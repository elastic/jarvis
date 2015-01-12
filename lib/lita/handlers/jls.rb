require "cabin"
require "tmpdir"
require "tempfile"
require "fileutils"
require "insist"
require "uri"
require "lita-jls/bot_builder"
require "lita-jls/repository"
require "lita-jls/github_url_parser"
require "lita-jls/util"

# TODO(sissel): This code needs some suuuper serious refactoring and testing improvements.
# TODO(sissel): Remove any usage of Rugged. This library requires compile-time
# settings of libgit2 and that's an annoying battle.

module Lita
  module Handlers
    class Jls < Handler
      include LitaJLS::Util

      route /^merge(?<dry>\?)? (?<pr_url>[^ ]+) (?<branchspec>.*)$/, :merge,
        :command => true,
        :help => { "merge https://github.com/ORG/PROJECT/pull/NUMBER branch1 [branch2 ...]" => "merges a PR into one or more branches. To see if a merge is successful, use 'merge? project#pr branch1 [branch2 ...]" }

      route /^cla(?<dry>\?)? (?<pr_url>[^ ]+)$/, :cla,
        :command => true,
        :help => { "cla https://github.com/ORG/PROJECT/pull/NUMBER" => "CLA check for a giaven PR" }

      route /^\(tableflip\)$/, :tableflip,
        :command => true,
        :help => { "(tableflip)" => "Fix whatever just broke. Probably git is going funky, so I will purge my local git junk" }

      route /^ping/, :ping, :command => true

      route /^publish\s(?<git_url>[^ ]+)$/, :publish,
        :command => true,
        :restrict_to => :logstash,
        :help => { 'publish https://github.com/ORG/project' => 'Install dependencies, Run test, build gem, publish and compare version on rubygems' }

      route /^(why computer(s?) so bad\?|explain)/i, :pop_exception,
        :command => true,
        :help => { 'explain or why computers so bad?' => 'return the last exception from redis' }

      route /^migrate_pr (?<source_url>[^ ]+) (?<destination_url>[^ ]+)$/, :migrate_pr,
            :command => true,
            :help => { 'migrate_pr https://github.com/elasticsearch/logstash/pull/1452 "\
+          "https://github.com/logstash-plugins/logstash-codec-line' => 'migrate pr from one repo to another' }

      REMOTE = "origin"
      URLBASE = "https://github.com/"
      LIMIT_EXCEPTIONS_HISTORY = 20

      RUBY_VERSION = "jruby-1.7.16"

      on :loaded, :setup

      def self.default_config(config)
        config.default_organization = nil
      end

      def pop_exception(msg)
        public_response = ['Commencing automated assembly. Estimated completion time is five hours.',
                           'That is the only way, sir.',
                           'Sir, please may I request just a few hours to calibrate.' ]

        e = @redis.lpop(:exception)

        msg.reply(public_response.sample)

        logger.debug("pop exception", :exception => e)

        if e
          e = JSON.parse(e) 

          msg.reply_privately("exception: #{e.delete('exception')}")
          msg.reply_privately("message: #{e.delete('message')}")
          msg.reply_privately("backtrace: #{e.delete('backtrace')}")

          # Print the remaining context
          e.each do |key, value|
            msg.reply_privately("#{key}: #{value}")
          end
        else
          msg.reply_privately("No exception saved.")
        end
      end

      def push_exception(e, context = {})
        error = {
          "exception" => e.exception,
          "message" => e.message,
          "backtrace" => e.backtrace,
        }.merge(context)

        @redis.lpush(:exception, error.to_json)
        @redis.ltrim(:exception, 0, LIMIT_EXCEPTIONS_HISTORY)
      end

      def publish(msg)
        git_url = msg.match_data["git_url"]

        logger.info('publish', :url => git_url)

        github_parser = LitaJLS::GithubUrlParser.parse(git_url, :link => :repository)
        github_parser.validate!

        repository = LitaJLS::Repository.new(github_parser)
        repository.clone
        repository.switch_branch('master')

        builder = LitaJLS::BotBuilder.new(repository.git_path, { :ruby_version => RUBY_VERSION })

        msg.reply("publishing (allthethings) for project: #{builder.project_name} branch: master")

        reporter = LitaJLS::Reporter::HipChat.new(builder.build)
        reporter.format(msg)
      rescue => e
        push_exception(e, :project => "#{github_parser.user}/#{github_parser.project}")
        msg.reply("(stare) Error: #{e.inspect}")
        raise
      end # def publish

      def ping(msg)
        msg.reply("(chompy)")
      end

      def setup(*args)
        ENV["PAGER"] = "cat"
        @@logger_subscription ||= logger.subscribe(STDOUT)

        @redis ||= Redis::Namespace.new("opsbot", redis: Lita.redis)
      end

      def cla(msg)
        @cla_uri = config.cla_uri
        pull = msg.match_data["pr_url"]
        pull_path = URI.parse(pull).path
        _, user, project, _, pr = pull_path.split("/")
        cla?("#{user}/#{project}", pr)
        msg.reply("#{user}/#{project}##{pr} CLA OK (freddie)")
      rescue => e
        msg.reply("cla check error: #{e}")
        push_exception(e, :project => "#{user}/#{project}", :pr => pr)
      end

      def migrate_pr(msg)
        source_url = msg.match_data["source_url"]
        destination_url = msg.match_data["destination_url"]
        if source_url.nil? || destination_url.nil?
          raise "Invalid paramaters provided #{msg}"
        end

        destination_github_parser = parse_github_url(destination_url)
        source_github_parser = parse_github_url(source_url)

        pr_num = source_github_parser.pr
        source_github_pr = github_get_pr("#{source_github_parser.user}/#{source_github_parser.project}", pr_num)

        # Clone destination dir, patch and then push branch
        repository = LitaJLS::Repository.new(destination_github_parser)
        repository.clone if Dir["#{repository.git_path}/*"].empty?
        repository.switch_branch("master")

        # create a branch like pr/1234
        pr_branch = "bot-migrated-pr/#{pr_num}"
        repository.delete_local_branch(pr_branch, true)
        repository.switch_branch(pr_branch, true)

        patch_file = download_patch(source_github_pr[:patch_url])

        # Apply patch on repo
        begin
          repository.git_patch(patch_file.path)
        rescue => e
          msg.reply("Error while migrating pr: #{e}")
          push_exception(e, :source_url => source_url,
                         :destination_url => destination_url)
        ensure
          patch_file.unlink
        end

        # create the migrated PR in the destination repo
        github_create_pr("#{destination_github_parser.user}/#{destination_github_parser.project}",
                         pr_branch, source_github_pr[:title], source_github_pr[:body])
      end

      @private
      # downloads the patch file in mail format and saves it to a file
      def download_patch(pr_url)
        http = Faraday.new("https://github.com")
        response = http.get(URI.parse(pr_url).path)
        if response.status != 200
          raise "Unable to fetch pull request #{pr_url}"
        end

        patch_file = Tempfile.new("#{pr_num}.patch")

        begin
          #TODO: Use chunked writes
          patch_file.write(response.body)
          patch_file.close
        rescue => e
          raise "Error while downloading pr: #{pr_url}, exception #{e}"
        end

        return patch_file
      end

      @private
      def parse_github_url(url)
        github_parser = LitaJLS::GithubUrlParser.parse(url, :link => :repository)
        github_parser.validate!
        return github_parser
      end

      def merge(msg)
        @cla_uri = config.cla_uri
        FileUtils.mkdir_p(workdir) unless File.directory?(workdir)
        pull = msg.match_data["pr_url"]
        pull_path = URI.parse(pull).path
        _, user, project, _, pr = pull_path.split("/")

        if user.nil? || project.nil? || pr.nil? || pull !~ /^https:\/\/github.com\//
          raise "Invalid URL. Expected something like: https://github.com/elasticsearch/snacktime/pull/12345"
        end

        branchspec = msg.match_data["branchspec"]
        dry_run = msg.match_data["dry"]

        begin
          cla?("#{user}/#{project}", pr)
        rescue => e
          msg.reply("(firstworldproblems) cla check failed for #{user}/#{project}##{pr}.\n #{e}")
          push_exception(e, :project => "#{user}/#{project}", :pr => pr)
          return
        end

        url = File.join(URLBASE, user, project)
        #git_url = "git@github.com:/#{user}/#{project}.git"
        git_url = url
        pr_url = File.join(url, "pull", "#{pr}.patch")
        gitpath = gitdir(project)
        branches = branchspec.split(/\s+/)

        logger.info("Cloning git repo", :url => git_url, :gitpath => gitpath)
        repo = clone_at(git_url, gitpath)

        git(gitpath, "am", "--abort") if File.directory?(".git/rebase-apply")

        # TODO(sissel): Fetch the PR patch
        logger.info("Fetching PR patch", :url => pr_url)
        http = Faraday.new("https://github.com")
        response = http.get(URI.parse(pr_url).path)
        if !response.success?
          logger.warn("Failed fetching patch", :url => pr_url, :status => response.status, :headers => response.headers)
          msg.reply("(grumpycat) Failed fetching patch. Cannot continue!")
          return
        end

        patch = response.body

        # For each branch, try to merge
        repo = gitpath
        branches.each do |branch|
          begin
            logger.info("Switching branches", :branch => branch, :repo => gitpath)
            git(gitpath, "checkout", branch)
            git(gitpath, "reset", "--hard", "#{REMOTE}/#{branch}")
            git(gitpath, "pull", "--ff-only")
            apply_patch(repo, patch) do |commit|
              # Append the PR number to commit message

              # Use "Fixes #XYZ" to make the PR get closed upon commit.
              # https://help.github.com/articles/closing-issues-via-commit-messages
              commit[:message] += "\nFixes ##{pr}"
            end
          rescue => e
            push_exception(e, :project => "#{user}/#{project}", :pr => pr, :branch => branch)
            msg.reply("(jackie) Failed attempting to merge #{user}/#{project}##{pr} into #{branch}: #{e}")
            raise
          end
        end

        # At this point, all branches merged successfully. Time to push!
        if dry_run
          msg.reply("(success) Merging was successful #{user}/#{project}##{pr} into: #{branchspec}.\n(but I did not push it)")
        else
          msg.reply("(success) #{user}/#{project}##{pr} merged into: #{branchspec}")
          git(gitpath, "push", REMOTE, *branches)

          labels = branches.reject { |b| b == "master" }
          github_issue_label("#{user}/#{project}", pr.to_i, labels)
        end
        github_issue_comment("#{user}/#{project}", pr.to_i, "Merged sucessfully into #{branchspec}!")
      rescue => e
        push_exception(e, :project => "#{user}/#{project}", :pr => pr, :branch => branches)
        msg.reply("(stare) Error: #{e.inspect}")
        raise
      end # def merge

      def tableflip(msg)
        logger.debug("(fliptable), remove the git directory")

        begin
          dir = workdir("gitbase")
          insist { dir } =~ /\/lita-jls/ # Just in case, before we go purging things...
          FileUtils.rm_r(dir) if File.directory?(dir)
          msg.reply("Git: (tableflip) (success)")
        rescue => e
          push_exception(e)
          msg.reply("Git: (tableflip) (huh): #{e}")
          raise e
        end
      end
    end # class Jls

    Lita.register_handler(Jls)
  end
end
