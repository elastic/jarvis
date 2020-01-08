require "clamp"
require "stud/temporary"
require "jarvis/exec"
require "jarvis/env_utils"
require "jarvis/logstash_helper"
require "jarvis/github/project"

module Jarvis module Command class Run < Clamp::Command
  banner "Execute a command against a repository (kind of like bundle exec ...)"

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."
  option "--env", "ENV", "ENV variables passed to task.", :default => 'JARVIS=true LOGSTASH_SOURCE=false' # to be able to bundle wout LS
  option "--branch", "BRANCH", "The branch to run from.", :default => 'master'

  parameter "PROJECT", "The project URL" do |url|
    Jarvis::GitHub::Project.parse(url)
  end
  parameter "SCRIPT ...", "The script runner", :attribute_name => :script

  def execute
    self.workdir = Stud::Temporary.pathname if workdir.nil?

    logs = []
    logger = ::Cabin::Channel.new
    logger.subscribe(logs)
    logger.subscribe(STDOUT)
    logger.level = :info

    logger.info("Cloning repo", :url => project.git_url)
    git = Jarvis::Git.clone_repo(project.git_url, workdir)

    task = "#{script.join(' ')}"
    puts ":ninja: Trying to run `#{task}` from #{project.organization}/#{project.name} (branch: #{branch})"

    git.checkout(branch)
    context = logger.context
    context[:operation] = 'run'
    context[:branch] = branch

    commands = [ "bundle install", ["ruby -rbundler/setup -S", *script] ]

    commands.each do |command|
      context[:command] = command
      puts I18n.t("lita.handlers.jarvis.publish command", :command => command)
      Jarvis.execute(command, git.dir, env, logger)

      # Clear the logs if it was successful
      logs.clear unless logger.debug?
    end
    context.clear
    git.reset
    git.clean(force: true)

    puts ":success: Finished task `#{task}` from #{project.organization}/#{project.name} (branch: #{branch})"

    puts logs.join("\n")
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :command => 'run')
  end

end end end
