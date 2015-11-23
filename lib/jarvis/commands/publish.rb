require "clamp"
require "net/http"
require "i18n"
require "json"
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
    
    build = build_report(project)
    workdir_sha1 = Jarvis::Git.sha1(workdir) 

    if build.sha1 = workdir_sha1
      puts I18n.t("lita.handlers.jarvis.sha1 dont match", :workdir_sha1 => workdir_sha1, :build_sha1 => build.sha1)
      return -1
    end

    if !build.success?
      puts I18n.t("lita.handlers.jarvis.build is not successful", :build_url => build.url, :workdir_sha1 => workdir_sha1, :build_sha1 => build.sha1)
      return -1
    end

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
 
  class BuildReport
    attr_reader :job_name, :sha1, :status, :url

    def initialize(job_name, sha1, status, url)
      @job_name = job_name
      @sha1 = sha1
      @status = status
    end

    def success?
      status == "SUCCESS"
    end
  end

  def build_report(project)
    job_name = "#{project.name}-unit" # we only test master and PR and not the core v1 branch

    url = "http://build-eu-00.elastic.co/job/#{job_name}/lastStableBuild/api/json"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Get.new(uri.path)

    response = http.request(req)
    JSON.parse(reponse.body)

    sha1 = data["buildsByBranchName"]["origin/master"]["marked"]["SHA1"]
    status = data["result"]
    url = data["url"]

    return BuildReport.new(job_name, sha1, status, url)
  end
end end end
