require "rugged"
require "cabin"
require "fileutils"
require "uri"

module LitaJLS 
  module Logger
    def logger
      return @logger if @logger
      @logger = Cabin::Channel.get
      @logger.level = :debug if ENV["DEBUG"]
      @logger
    end
  end

  module Util
    include Logger

    private

    # Clone a git url into a local path.
    #
    # This caches a remote git repo and performs a clone against that in
    # order to make subsequent clones faster. It will try to provide the
    # latest (via 'git fetch') after cloning is complete.
    def clone_at(url, gitpath)
      # TODO(sissel): Refactor this into two 'clone' calls.
      logger.debug("clone_at", :url => url, :gitpath => gitpath)

      # Cache a remote git url so that we can clone it more quickly in the
      # future.
      cachebase = gitdir(File.join("_"))
      Dir.mkdir(cachebase) unless File.directory?(cachebase)
      cache = File.join(cachebase, File.basename(gitpath))
      logger.info("Cloning to cache", :url => url, :cache => cache)
      begin
        #Rugged::Repository.clone_at(url, cache)
        git(".", "clone", url, cache)
      rescue => e
        logger.debug("clone_at failed, trying to open repo instead", :cache => cache, :error => e)
        #require "pry"; binding.pry
        # Verify some kind of git works here
        git(cache, "log", "-n0")
        #Rugged::Repository.new(cache)
      end
      remote = "origin"
      
      # Update from remote if already cloned
      logger.debug("Fetching a remote", :cache => cache, :remote => remote)
      #cacherepo.fetch(remote)
      git(cache, "fetch", remote)

      # Clone from cache.
      # This allows us to have multiple local working/clones and just keep
      # cloning from the local cache. The alternative is to clone from the
      # remote every time we do a new clone_at, and that would be slow through
      # github or gitlab.
      logger.info("Cloning from cache", :cache => cache, :gitpath => gitpath)
      begin
        #Rugged::Repository.clone_at(cache, gitpath)
        git(".", "clone", cache, gitpath)
      rescue => e
        logger.info(e)
        logger.debug("clone_at from cache failed, trying to open repo instead", :repo => gitpath, :cache => cache)
        #Rugged::Repository.new(gitpath)
      end
      git(gitpath, "remote", "set-url", remote, url)
      #repository.remotes.delete(remote)
      #repository.remotes.create(remote, url)
      # I can't figure out how to do auth with Rugged, so let's set the push target to be ssh
      # so at least we can `git push` via cli.
      # TODO(sissel): Figure out how to do auth in Rugged. Related: https://github.com/libgit2/rugged/issues/422
      uri = URI.parse(url)
      push_url = "git@github.com:#{uri.path}.git"
      git(gitpath, "remote", "set-url", "--push", remote, push_url)
      git(gitpath, "fetch")

      # TODO(sissel): pull --ff-only?
      gitpath
    end # def clone_at

    def gitdir(project)
      if !@gitdir
        @gitdir = workdir("gitbase")
        FileUtils.mkdir_p(@gitdir) unless File.directory?(@gitdir) 
        logger.debug("Git dir", :path => @gitdir)
      end
      path = File.join(@gitdir, project)
      Dir.mkdir(path) unless File.directory?(path)
      path
    end # def gitdir

    def workdir(path=nil)
      return @workdir if @workdir
      @workdir = File.join(Dir.tmpdir, "lita-jls")
      Dir.mkdir(@workdir) unless File.directory?(@workdir)
      if path.nil?
        @workdir
      else
        File.join(@workdir, path)
      end
    end # def workdir

    def apply_patch(repo, patch_body, &block)
      require "mbox"
      require "time"
      # The github '.patch' format is an mbox containing one mail+patch per
      # commit.
      mbox = Mbox.new(patch_body)
      mbox.each_with_index do |mail, i|
        commit = apply_commit(repo, mail, &block)
        logger.info("Created commit", :commit => commit, :patch => i)
      end
    end # def apply_patch

    def apply_commit(repo, mail, &block)
      from_re = /([^<]+) (<[^>]+>)/
      match = from_re.match(mail.headers["from"])
      name = match[1].gsub(/(^")|("$)/, "")
      email = match[2].gsub(/^<|>$/, "")
      if name.nil? || email.nil?
        raise "Unable to parse name and email from '#{mail.headers["from"]}'. Cannot continue"
      end
      time = Time.parse(mail.headers["date"])
      #File.write("/tmp/x", patch)

      # Take the email subject but strip [PATCH] or [PATCH N/M] out.
      subject = mail.headers["subject"].gsub(/^\[PATCH[^\]]*\] /, "")
      # The email body (minus the patch itself) is the rest of the commit message
      description = /^(?<description>.*\n)?---\n.*$/m.match(mail.content.first.content)["description"] || ""

      if subject.empty? && description.empty?
        raise "Empty commit message (no subject or description). Refusing to continue."
      end

      #patch = mail.content.first.content.gsub(/^(?:.*\n)?---\n.*?\n\n/m, "")
      #patch += "\n" if patch[-1,1] != "\n"
      # Patch must have a trailing newline.
      patch = [mail.headers, mail.content, ""].join("\n")
      #require "pry";binding.pry

      # Apply the code change to the git index
      Dir.chdir(File.dirname(repo.path)) do
        cmd = ["git", "am"]
        IO.popen(cmd, "w+") do |io|
          io.write(patch)
          io.close_write
          logger.pipe(io => :debug)
        end
        status = $?
        if !status.success?
          logger.warn("Git am failed", :code => status.exitstatus, :command => cmd, :pwd => Dir.pwd)
          raise "Git am failed: #{cmd.join(" ")}"
        end
        logger.info("Git apply successful!", :code => status.exitstatus, :command => cmd, :pwd => Dir.pwd)
      end

      # Because we changed git outside of Rugged::Repository, we'll want to reload it so 
      # it gets the newest index.

      # Commit this patch
      #index = repo.index

      # Because we did `git apply` via CLI, we'll need Rugged to reload the index data from disk.
      #index.reload
      #tree = index.write_tree(repo)

      # Combine subject + description for the full commit message
      message = "#{subject}\n\n#{description}"

      commit_settings = { 
        #:author => { :email => email, :name => name, :time => time },
        #:committer => { :email => "jls@semicomplete.com", :name => "Jordan Sissel", :time => Time.now },
        :message => message
      }

      # Allow any modifications to the commit object itself.
      block.call(commit_settings)

      # Update HEAD to point to our new commit
      #commit_settings.merge!(
        #:update_ref => "HEAD",
        #:parents => [repo.head.target],
        #:tree => tree
      #)
      #Rugged::Commit.create(repo, commit_settings)

      Dir.chdir(File.dirname(repo.path)) do
        cmd = ["git", "commit", "--amend", "-F-"]
        IO.popen(cmd, "w+") do |io|
          io.write(commit_settings[:message])
          io.close_write
          logger.pipe(io => :debug)
        end
      end

    end # def apply_commit

    def system!(*args)
      logger.debug("Running command", :args => args)
      # TODO(sissel): use Open4
      IO.popen(args, "r") do |io|
        logger.pipe(io => :debug)
      end
      status = $?
      return if status.success?
      raise "Command failed; #{args.inspect}"
    end

    def github_client
      require "octokit"
      # This requires you have ~/.netrc setup correctly
      # I don't know if it works with 2FA
      @client ||= Octokit::Client.new(:netrc => true).tap do |client|
        client.login
        client.auto_paginate = true
      end
    end # def client

    def github_issue_label(project, issue, labels)
      github_client.add_labels_to_an_issue(project, issue, labels)
    end # def github_issue_label

    def git(gitdir, *args)
      Dir.chdir(gitdir) do
        system!("git", *args)
      end
    end
  end # module Util
end # module LitaJLS
