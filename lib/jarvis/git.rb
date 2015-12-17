require "git"
require "jarvis/error"
require "rfc2047"

module Jarvis module Git
  class PushFailure < ::Jarvis::Error; end
  class MergeProblem < ::Jarvis::Error; end
  class ParseProblem < ::Jarvis::Error; end
  PATCH_MESSAGE_SEPARATOR = "---\n"

  # Returns a Git::Base after cloning the repo
  def self.clone_repo(git_url, workdir)
    name = git_url.split("/").last.gsub(/\.git$/, "")
    ::Git.clone(git_url, name, :path => workdir)
  end

  # Retrieve a commit hash from a patch
  #
  # - mail: a Mbox::Mail instance
  def self.patch_hash(mail)
    raise ParseProblem, "Not implemented"
  end

  # Retrieve a formatted git message from a patch
  #
  # - mail: a Mbox::Mail instance
  def self.patch_message(mail)
    description = mail.content.first.content.split(PATCH_MESSAGE_SEPARATOR, 2).first

    if description.empty?
      raise ParseProblem, "Description in a commit cannot be empty."
    end

    description
  end

  def self.push_to_branches(git, logger, branches)
    logger[:operation] = "git push"
    pid, stdin, stdout, stderr = Open4::popen4("git", "-C", "#{git.dir}", "push", "origin", *branches)
    stdin.close
    logger.pipe(stdout => :info, stderr => :error)
    _, status = Process::waitpid2(pid)
    raise PushFailure, "git push failed" unless status.success?
  end

  # Apply a diff to a git repo.
  #
  # - git: a Git::Base (from Git.init, Git.clone, etc)
  # - path: the path to the diff file
  # - logger: a Cabin::Channel
  # - message: the commit message
  def self.apply_diff_from_file(git, path, logger, message)
    raise ParseProblem, "Not implemented"
  end

  # Apply a mail-format patch to a git repo.
  #
  # - git: a Git::Base (from Git.init, Git.clone, etc)
  # - mail: a Mbox::Mail instance
  # - logger: a Cabin::Channel
  # - &block: optional. If provided, will be passed the commit description as
  #   the only argument. The return value will be used as the new description.
  def self.apply_mail(git, mail, logger, &block)
    cleanup = []
    # github prefixes the subject line with [PATCH], remove that part.
    subject = clean_subject(mail.headers[:subject])
    logger.info("Working on a patch", :subject => subject)
    # The email body (minus the patch itself) is the rest of the commit message
    description, diff = mail.content.first.content.split(PATCH_MESSAGE_SEPARATOR, 2)

    if subject.empty? && description.empty?
      raise MergeProblem, "Subject or description in a commit cannot be empty. Aborting merge attempt."
    end

    description = block.call(description) if block_given?
    patch = Stud::Temporary.file
    cleanup << patch.path
    # Patches must have a trailing newline
    patch.write([mail.headers.to_s, description, PATCH_MESSAGE_SEPARATOR, diff, ""].join("\n"))
    patch.close

    # We have to use system() here because the ruby Git library fails due to requiring chdir first.
    # If we chdir, we cannot do multiple git actions simultaneously.
    logger.info("Applying patch")
    pid, stdin, stdout, stderr = Open4::popen4("git", "-C", "#{git.dir}", "am", "--", patch.path)
    stdin.close
    logger.pipe(stdout => :info, stderr => :error)

    # Wait for the `git am` subprocess to finish.
    _, status = Process::waitpid2(pid)
    raise MergeProblem, "Merging patch failed. Aborting." unless status.success?
  ensure
    cleanup.each do |path|
      File.unlink(path)
    end
  end

  def self.clean_subject(subject)
    Rfc2047.decode(subject.gsub(/^\[PATCH\] /, ""))
  end

  def self.config(git, key, value)
    # ruby Git doesn't support this, so we do it ourselves.
    system("git", "-C", git.dir.to_s, "config", key, value)
  end
end end
