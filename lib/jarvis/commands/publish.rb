require "clamp"
require "i18n"
require "stud/temporary"
require "jarvis/exec"
require "jarvis/github/project"

module Jarvis module Command class Publish < Clamp::Command
  banner "Publish a logstash plugin"

  option "--committer-email", "EMAIL", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.email` and `git config --get user.email`)."
  option "--committer-name", "NAME", "The git committer name to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."
  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."
  option "--github-token", "GITHUB_TOKEN", "Your github auth token", :required => true

  parameter "PROJECT", "The project URL" do |url|
    Jarvis::GitHub::Project.parse(url)
  end
  parameter "[BRANCH] ...", "The branches to publish", :default => [ "master" ], :attribute_name => "branches"

  TASKS = [ 'bundle install', 'bundle exec rake vendor', 'bundle exec rake publish_gem' ].freeze
  def execute
    self.workdir = Stud::Temporary.pathname if workdir.nil?

    logs = []
    logger = ::Cabin::Channel.new
    logger.subscribe(logs)
    logger.subscribe(STDOUT) if STDOUT.tty?
    logger.level = :debug

    logger.info("Cloning repo", :url => project.git_url)
    git = Jarvis::Git.clone_repo(project.git_url, workdir)

    branches.each do |branch|
      logger.info("Switching branches", :branch => branch)
      git.checkout(branch)
      context = logger.context
      context[:operation] = "publish"
      context[:branch] = branch

      TASKS.each do |command|
        context[:command] = command
        Jarvis.execute(Shellwords.shellsplit(command), logger)
      end
      context.clear()
      git.reset
      git.clean(force: true)
    end

    puts I18n.t("lita.handlers.jarvis.publish success", organization: project.organization, project: project.name, branches: branches.join(", "))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge", :logs => logs.join("\n"))
  end
end end end
