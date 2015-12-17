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
require "jarvis/fetch"
require "jarvis/defer"
require "mbox"

module Jarvis module Command class Backport < Clamp::Command
  class PushFailure < ::Jarvis::Error; end
  class Bug < ::Jarvis::Error; end

  banner "Backport a pull request to one or more branches."

  option "--committer-email", "EMAIL", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.email` and `git config --get user.email`)."
  option "--committer-name", "NAME", "The git committer name to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."
  option "--github-token", "GITHUB_TOKEN", "Your github auth token", :required => true

  parameter "URL", "The URL to backport"
  parameter "BRANCHES ...", "The branches to which to backport", :attribute_name => :branches

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
    logger.info("Fetching patch", :url => pr.patch_url)
    patch_file = Jarvis::Fetch.file(pr.patch_url)
    defer.do { File.unlink(patch_file.path) }

    # Download the diff
    logger.info("Fetching diff", :url => pr.patch_url)
    diff_file = Jarvis::Fetch.file(pr.diff_url)
    defer.do { File.unlink(diff_file.path) }

    # Clone the git repo
    logger.info("Cloning repo", :url => pr.git_url)
    git = Jarvis::Git.clone_repo(pr.git_url, workdir)

    # ruby Git library doesn't seem to support setting per-repo configuration,
    # so we call `git` directly.
    logger.info("Setting local git committer details", :email => committer_email, :name => committer_name)
    Jarvis::Git.config(git, "user.email", committer_email)
    Jarvis::Git.config(git, "user.name", committer_name)

    commits = []
    patches = Mbox.new(patch_file)

    # create backport commit message
    messages = patches.map do |patch|
      hash = ::Jarvis::Git.patch_hash(patch)
      message = ::Jarvis::Git.patch_message(patch)
      "Original commit: \##{hash}\n\n#{message}"
    end
    message = messages.join("\n\n")

    # applies PR diff as a single commit on target branches
    branches.each do |branch|
      logger[:branch] = branch

      ::Jarvis::Git.work_on_branch(git, logger, branch)

      hash = ::Jarvis::Git.apply_diff_from_file(git, logger, diff_file.path, message)

      commits << { :branch => branch, :commit => hash }
      logger[:branch] = nil
    end

    # Render comment to string before attempting to push branches
    comment = Jarvis::Template.render("github_backport_comment.mustache",
                                      :committer => committer_name,
                                      :commits => commits)

    # Push to branches
    Jarvis::Git.push_to_branches(git, logger, branches)

    # Comment on PR
    Jarvis::GitHub.post_comment(pr, comment)

    # TODO(sissel): Set labels on PRs
    puts I18n.t("lita.handlers.jarvis.backport success", organization: pr.organization, project: pr.project, number: pr.number, branches: branches.join(","))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "backport", :logs => logs.join("\n"))
  ensure
    defer.run
  end

end end end
