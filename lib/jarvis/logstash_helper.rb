require 'jarvis/fetch'
require 'jarvis/exec'
require 'tmpdir'
require 'json'

module Jarvis class LogstashHelper

  class UnresolvedLogstashVersion < ::Jarvis::Error ; end

  def self.download_and_extract_gems_if_necessary(version)
    if download_version = version.to_s.match(/^#(\{|\()(.*?)(\}|\))$/) # '#{7.5.1}' or '#{latest}'
      download_version = download_version[2]
      if download_version.match(/\d\.\d\.\d(\.\d)?/)
        version = download_version
      else # need to resolve '7.x' or 'releases[last]'
        version = resolve_logstash_version(download_version)
      end
    end

    return version if version.nil? || version.empty? || %w{ true false }.include?(version)

    ls_helper = Jarvis::LogstashHelper.new(version)
    ls_helper.download_and_extract_gems
  end

  def self.resolve_logstash_version(version)
    log "Fetching logstash_releases.json", url: LS_RELEASES_JSON
    download(LS_RELEASES_JSON) do |file|
      versions_data = JSON.parse(file.read)

      if (data = versions_data['releases']).is_a?(Hash)
        v = data[version]
        return v if v
        # TODO won't do once LS 10.0.0 is released
        # enrich so we can resolve 'releases[last]' :
        data['last'] ||= data.sort.last[1]
        data['first'] ||= data.sort.first[1]
      end

      if (data = versions_data['snapshots']).is_a?(Hash)
        v = data[version]
        return v if v
        # TODO won't do once LS 10.0.0 is released
        # enrich so we can resolve 'snapshots[first]' :
        data['last'] ||= data.sort.last[1]
        data['first'] ||= data.sort.first[1]
      end

      version = { 'last' => 'releases[last]', 'latest' => 'releases[last]' }.fetch(version, version) # aliases
      v = versions_data.dig *version.split(/\[(.*?)\]/).reject(&:empty?) # 'releases[last]' => 'releases', 'last'

      raise UnresolvedLogstashVersion.new(version.inspect) unless v

      return v
    end
  end

  def self.download(url, &block)
    Jarvis::Fetch.file(url, &block)
  end

  def self.log(msg, data = {})
    if logger = Jarvis.logger
      logger.info(msg, data)
    else
      msg = "#{msg} #{data.inspect}" if data.any?
      puts(msg)
    end
  end

  BASE_URL = 'https://artifacts.elastic.co/downloads/logstash'
  LS_RELEASES_JSON = 'https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json'

  def initialize(version)
    @base = "logstash-#{version}"
    @url = File.join(BASE_URL, "#{@base}.tar.gz")
  end

  # @return a LS_HOME path
  def download_and_extract_gems
    tmp_dir = extract(download, paths: [ "#{@base}/logstash-core-plugin-api", "#{@base}/logstash-core" ])
    return File.join(tmp_dir, @base)
  end

  def download(&block)
    self.class.log "Downloading #{@base}", url: @url
    self.class.download(@url, &block)
  end

  def extract(tgz, paths: [])
    ls_dir = Dir.mktmpdir
    self.class.log "Extracting #{tgz.path}", dir: ls_dir
    Jarvis.execute("tar -zxvf #{tgz.path} #{paths.join(' ')}", ls_dir) # -C #{ls_dir}
    ls_dir
  end

end end
