require "clamp"
require "open4"
require "cabin"
require "i18n"
require "git"
require "stud/temporary"
require "jarvis/github/pull_request"
require "jarvis/git"
require "jarvis/fetch"
require "mbox"

module Jarvis module Command class Merge < Clamp::Command
  class PushFailure < ::Jarvis::Error; end

  banner "Merge a pull request into one or more branches."

  option "--committer-email", "EMAIL", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.email` and `git config --get user.email`)."
  option "--committer-name", "NAME", "The git committer name to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."

  parameter "URL", "The URL to merge"
  parameter "BRANCHES ...", "The branches to merge", :attribute_name => :branches

  def pr
    @pr ||= Jarvis::GitHub::PullRequest.parse(url)
  end

  def execute
    cleanup = []
    logs = []
    logger = ::Cabin::Channel.new
    logger.subscribe(logs)
    logger.subscribe(STDOUT) if STDOUT.tty?
    logger.level = :debug

    self.workdir = Stud::Temporary.pathname if workdir.nil?

    Dir.mkdir(workdir) unless File.directory?(workdir)

    # Download the patch
    logger.info("Fetching PR", :url => pr.patch_url)
    patch_file = Jarvis::Fetch.file(pr.patch_url)
    cleanup << patch_file.path

    # Clone the git repo
    logger.info("Cloning repo", :url => pr.git_url)
    git = Jarvis::Git.clone_repo(pr.git_url, workdir)

    # ruby Git library doesn't seem to support setting per-repo configuration,
    # so we call `git` directly.
    system("git", "-C", git.dir.to_s, "config", "user.email", committer_email)
    system("git", "-C", git.dir.to_s, "config", "user.email", committer_name)

    branches.each do |branch|
      logger[:branch] = branch
      logger.info("Working on a branch")
      git.checkout(branch)

      patches = Mbox.new(patch_file)
      patches.each do |mail|
        ::Jarvis::Git.apply_mail(git, mail, logger) do |description|
          # Append the 'Fixes #1234' to the bottom of the commit message for
          # whatever PR this is..
          description + "\nFixes \##{pr.number}"
        end
        logger.info("Patch successfully applied")
      end
      logger[:branch] = nil
    end

    # Push to branches
    logger[:operation] = "git push"
    pid, stdin, stdout, stderr = Open4::popen4("git", "-C", "#{git.dir}", "push", "origin", *branches)
    stdin.close
    logger.pipe(stdout => :info, stderr => :error)
    _, status = Process::waitpid2(pid)
    raise PushFailure, "git push failed" unless status.success?

    # Set labels on PRs
    puts I18n.t("lita.handlers.jarvis.merge success", organization: pr.organization, project: pr.project, number: pr.number, branches: branches.join(","))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge", :logs => logs.join("\n"))
  ensure
    cleanup.each do |path|
      File.unlink(path)
    end
  end

end end end
