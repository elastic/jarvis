require "clamp"
require "fileutils"
require "octokit"
require "mustache"
require "open4"
require "cabin"
require "i18n"
require "git"
require "stud/temporary"
require "jarvis/github/pull_request"
require "jarvis/git"
require "jarvis/fetch"
require "jarvis/defer"
require "mbox"

module Jarvis module Command class Merge < Clamp::Command
  class PushFailure < ::Jarvis::Error; end
  class Bug < ::Jarvis::Error; end

  banner "Merge a pull request into one or more branches."

  option "--committer-email", "EMAIL", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.email` and `git config --get user.email`)."
  option "--committer-name", "NAME", "The git committer name to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."
  option "--github-token", "GITHUB_TOKEN", "Your github auth token", :required => true

  parameter "URL", "The URL to merge"
  parameter "BRANCHES ...", "The branches to merge", :attribute_name => :branches

  def pr
    @pr ||= Jarvis::GitHub::PullRequest.parse(url)
  end

  def github
    return @github if @github
    @github = Octokit::Client.new
    @github.access_token = github_token
    @github.login
    @github
  end

  def execute
    defer = ::Jarvis::Defer.new
    logs = []
    logger = ::Cabin::Channel.new
    logger.subscribe(logs)
    logger.subscribe(STDOUT) if STDOUT.tty?
    logger.level = :debug
    logger[:context] = "#{pr.project}\##{pr.number}"

    if workdir.nil?
      self.workdir = Stud::Temporary.pathname
      defer.do { FileUtils.rm_r(workdir, :secure => true) }
    end
    Dir.mkdir(workdir) unless File.directory?(workdir)

    # Download the patch
    logger.info("Fetching PR", :url => pr.patch_url)
    patch_file = Jarvis::Fetch.file(pr.patch_url)
    defer.do { File.unlink(patch_file.path) }

    # Clone the git repo
    logger.info("Cloning repo", :url => pr.git_url)
    git = Jarvis::Git.clone_repo(pr.git_url, workdir)

    # ruby Git library doesn't seem to support setting per-repo configuration,
    # so we call `git` directly.
    logger.info("Setting local git committer details", :email => committer_email, :name => committer_name)
    Jarvis::Git.config(git, "user.email", committer_email)
    Jarvis::Git.config(git, "user.name", committer_name)

    commits = []
    branches.each do |branch|
      logger[:branch] = branch
      logger.info("Working on a branch")
      git.checkout(branch)

      commits << { :branch => branch, :commits => [] }
      patches = Mbox.new(patch_file)
      patches.each do |mail|
        ::Jarvis::Git.apply_mail(git, mail, logger) do |description|
          # Append the 'Fixes #1234' to the bottom of the commit message for
          # whatever PR this is..
          description + "\nFixes \##{pr.number}"
        end

        # Verify the committer is set correctly.
        data = git.lib.commit_data("HEAD")
        # format of the committer field is this: Your Name <foo@example.com> 1234567890 -0800
        _, name, email, *_ = /^([^<]+) <([^>]+)> \d+ [+-]\d+/.match(data["committer"]).to_a
        raise Bug, "Committer name didn't match: #{name} vs #{committer_name}" if name != committer_name
        raise Bug, "Committer email didn't match: #{email} vs #{committer_email}" if email != committer_email

        # Record the commit hash for this commit.
        commits.last[:commits] << git.revparse("HEAD") 
      end
      logger.info("Patch successfully applied")
      logger[:branch] = nil
    end

    template = File.join(File.dirname(__FILE__), "..", "..", "..", "templates", "github_merge_comment.mustache")
    comment = Mustache.render(File.read(template),
                              :committer => committer_name,
                              :commits => commits.each { |v| v[:commits] = v[:commits].join(", ") })

    # Push to branches
    logger[:operation] = "git push"
    pid, stdin, stdout, stderr = Open4::popen4("git", "-C", "#{git.dir}", "push", "origin", *branches)
    stdin.close
    logger.pipe(stdout => :info, stderr => :error)
    _, status = Process::waitpid2(pid)
    raise PushFailure, "git push failed" unless status.success?

    logger[:operation]  = "add comment"
    logger.info("Adding comment to issue")
    github.add_comment("#{pr.organization}/#{pr.project}", pr.number, comment)

    # TODO(sissel): Set labels on PRs
    puts I18n.t("lita.handlers.jarvis.merge success", organization: pr.organization, project: pr.project, number: pr.number, branches: branches.join(","))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge", :logs => logs.join("\n"))
  ensure
    defer.run
  end

end end end
