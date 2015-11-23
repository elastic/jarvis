require "clamp"
require "i18n"
require "stud/temporary"
require "jarvis/exec"
require "jarvis/github/project"

module Jarvis module Command class Publish < Clamp::Command
  banner "Publish a logstash plugin"

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."

  parameter "PROJECT", "The project URL" do |url|
    Jarvis::GitHub::Project.parse(url)
  end
  parameter "[BRANCH] ...", "The branches to publish", :default => [ "master" ], :attribute_name => "branches"

  TASKS = [ 'bundle install',
            'bundle exec rake vendor',
            'bundle exec rake publish_gem' ].freeze

  def execute
    self.workdir = Stud::Temporary.pathname if workdir.nil?

    logs = []
    logger = ::Cabin::Channel.new
    logger.subscribe(logs)
    logger.subscribe(STDOUT)
    logger.level = :info

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
        Jarvis.execute(command, logger, git.dir)

        # Clear the logs if it was successful
        logs.clear unless logger.debug?
      end
      context.clear()
      git.reset
      git.clean(force: true)
    end

    puts I18n.t("lita.handlers.jarvis.publish success", organization: project.organization, project: project.name, branches: branches.join(", "))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge", :logs => logs.collect { |l| l[:message] }.join("\n"))
  end
end end end
