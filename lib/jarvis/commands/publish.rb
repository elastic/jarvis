require "clamp"
require "net/http"
require "i18n"
require "json"
require "stud/temporary"
require "jarvis/exec"
require "jarvis/github/project"
require "gems"

module Jarvis module Command class Publish < Clamp::Command
  class RemoteVersionDontMatchLocal < ::Jarvis::Error; end
  class CommitHashDontMatch < ::Jarvis::Error; end
  class CIBuildFail < ::Jarvis::Error; end
  class NoGemspecFound < ::Jarvis::Error; end

  banner "Publish a logstash plugin"

  option "--workdir", "WORKDIR", "The place where this command will download temporary files and do stuff on disk to complete a given task."
  option "--force", :flag, "Dont check if the build pass on jenkins and try to publish anyway"

  parameter "PROJECT", "The project URL" do |url|
    Jarvis::GitHub::Project.parse(url)
  end
  parameter "[BRANCH] ...", "The branches to publish", :default => [ "master" ], :attribute_name => "branches"

  TASKS = [ "bundle install",
            "bundle exec rake vendor",
            "bundle exec rake publish_gem" ].freeze

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

      unless force?
        build = build_report(project)
        workdir_sha1 = Jarvis::Git.sha1(workdir) 

        if build.sha1 == workdir_sha1
          raise CommitHashDontMatch, "workdir_sha1: #{workdir_sha1}, build_sha1: #{build_sha1}"
        end

        if !build.success?
          raise CIBuildFail, "Expecting success got #{build.status}"
        end
      end

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

      check_version_match
    end


    puts I18n.t("lita.handlers.jarvis.publish success",
                :organization => project.organization,
                :project => project.name,
                :branches => branches.join(", "))
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class,
                :message => e.to_s,
                :stacktrace => e.backtrace.join("\n"),
                :command => "publish",
                :logs => logs.collect { |l| l[:message] }.join("\n"))
  end

  def check_version_match
    name, local_version = gem_specification
    remote_versions = Gems.versions(name).collect { |v| v["number"] }

    if !remote_versions.include?(local_version)
      raise RemoteVersionDontMatchLocal, "local version: #{local_version}, not in remove version #{remote_versions}"
    end
  end

  def gem_specification
    # HACK: if you are using the `real` bundler way of creating gem
    # You have to create a version.rb file containing the version number
    # and require the file in the gemspec. 
    # Ruby will cache this require and not reload it again in a long running
    # process like the bot.
    cmd = "ruby -e \"spec = Gem::Specification.load('#{gemspec}'); puts [spec.name, spec.version].join(',')\""

    pid, stdin, stdout, stderr = Open4::popen4(cmd)
    stdout.read.chomp.split(',')
  end

  def gemspec
    f = Dir.glob(File.join(workdir, "**/*.gemspec")).first
    if !f.nil? && File.file?(f)
      return f
    else
      raise NoGemspecFound, "No gemspec in #{workdir}"
    end
  end

  def extract_build_sha1(data)
    build_node = data.fetch("actions", []).select { |i| i.has_key?("lastBuiltRevision") }.first
    if build_node.nil?
      raise Bug, "Can't find the `lastbuiltRevision` node in the json document"
    end

    branch = build_node["lastBuiltRevision"].fetch("branch", []).first

    if branch.nil?
      raise "Can't find the branch node from the jenkins response"
    end

    return branch["SHA1"]
  end

  def build_report(project)
    # job format: logstash-plugin-input-beats-unit/
    job_name = "logstash-plugin-#{project.name.gsub(/logstash-/, '')}-unit" # we only test master and PR and not the core v1 branch

    url = "http://build-eu-00.elastic.co/job/#{job_name}/lastStableBuild/api/json"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Get.new(uri.path)

    response = http.request(req)
    data = JSON.parse(response.body)

    sha1 = extract_build_sha1(data)
    status = data["result"]
    url = data["url"]

    return BuildReport.new(job_name, sha1, status, url)
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

end end end
