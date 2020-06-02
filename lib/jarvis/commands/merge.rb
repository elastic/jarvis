require "clamp"
require "fileutils"
require "octokit"
require "mustache"
require "open4"
require "cabin"
require "git"
require "stud/temporary"
require "jarvis/github/pull_request"
require "jarvis/patches/i18n"
require "jarvis/git"
require "jarvis/github"
require "jarvis/fetch"
require "jarvis/defer"
require "mbox"

module Jarvis module Command class Merge < Clamp::Command
  include ::Jarvis::Github

  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8

  class PushFailure < ::Jarvis::Error; end
  class Bug < ::Jarvis::Error; end

  banner "Merge a pull request into one or more branches. Uses git merge for the first branch and git am for the rest."

  option "--committer-email", "EMAIL", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.email` and `git config --get user.email`)."
  option "--committer-name", "NAME", "The git committer name to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."

  option "--[no-]allow-multiple-commits", :flag, "Allow the Pull Request to be merged with multiple commits.", :default => false

  parameter "PR", "The PR URL to merge" do |url|
    Jarvis::GitHub::PullRequest.parse(url)
  end

  parameter "[BRANCHES] ...", "The branches to merge", :attribute_name => :branches

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

    # Clone the git repo
    logger.info("Cloning repo", :url => pr.git_url)
    git = Jarvis::Git.clone_repo(pr.git_url, workdir)

    # Download the patch
    logger.info("Fetching PR")
    pull = github.pull_request("#{pr.organization}/#{pr.project}", pr.number)
    if pull.commits > 1 && !allow_multiple_commits?
      raise "Pull request has more than 1 commit. Please consider squashing, or to override this check use: \"merge --allow-multiple-commits pr_url target_branch ..\""
    end

    git.lib.send(:command, "fetch", ["origin", "pull/#{pr.number}/head"])
    git.checkout("FETCH_HEAD")

    patch_file = File.join(workdir, "patch")
    File.write(patch_file, git.lib.send(:command, "format-patch", ["--stdout", pull.base.sha]))
    defer.do { File.unlink(patch_file) if File.exist?(patch_file) }

    # ruby Git library doesn't seem to support setting per-repo configuration,
    # so we call `git` directly.
    logger.info("Setting local git committer details", :email => committer_email, :name => committer_name)
    Jarvis::Git.config(git, "user.email", committer_email)
    Jarvis::Git.config(git, "user.name", committer_name)

    if branches.empty?
      target_branch = pull.base.ref
      logger.info("No branches given, merging to PR's base branch: #{target_branch}")
      branches << target_branch
      backport_branches = []
    else
      target_branch, *backport_branches = branches

      if pull.base.ref != target_branch
        raise "First branch in the list doesn't match the PR's target branch. Expected '#{pull.base.ref}', got '#{target_branch}'"
      end
    end

    commits = []

    unless pull.mergeable
      raise "Pull request can't be merged to #{target_branch} according to Github. Mergeable state: #{pull.mergeable_state}"
    end

    logger[:operation] = "git am"
    backport_branches.each do |branch|
      logger[:branch] = branch
      logger.info("Backport to branch: \"#{branch}\"")
      git.checkout(branch)

      commits << { :branch => branch, :commits => [] }
      patches = Mbox.new(File.new(patch_file, "r"))
      patches.each do |mail|
        ::Jarvis::Git.apply_mail(git, mail, logger)
        commits.last[:commits] << git.revparse("HEAD")
      end
      logger.info("Patch successfully applied")
      logger[:branch] = nil
    end

    # Merge to target branch
    logger[:operation] = "github merge"
    github.merge_pull_request("#{pr.organization}/#{pr.project}", pr.number, '', :merge_method => "rebase")
    logger.info("Merged to target branch: \"#{target_branch}\"")
    # Push to branches
    if backport_branches.any?
      logger[:operation] = "git push"
      pid, stdin, stdout, stderr = Open4::popen4("git", "-C", "#{git.dir}", "push", "origin", *backport_branches)
      stdin.close
      logger.pipe(stdout => :info, stderr => :error)
      _, status = Process::waitpid2(pid)
      raise PushFailure, "git push failed" unless status.success?
    end

    # let's give github some time to mark the PR as merged
    # otherwise it looks weird having the backport comment
    # before the target branch merge
    sleep(1)

    template = File.join(File.dirname(__FILE__), "..", "..", "..", "templates", "github_merge_comment.mustache")
    comment = Mustache.render(File.read(template),
                              :base => pull.base.ref,
                              :committer => committer_name,
                              :commits => commits.empty? ? nil : commits.each { |v| v[:commits] = v[:commits].join(", ") })

    logger[:operation]  = "add comment"
    logger.info("Adding comment to issue")
    github.add_comment("#{pr.organization}/#{pr.project}", pr.number, comment)

    # TODO(sissel): Set labels on PRs
    puts I18n.t("lita.handlers.jarvis.merge success", organization: pr.organization, project: pr.project, number: pr.number, branches: branches.join(","))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :command => "merge")
  ensure
    defer.run
  end

end end end
