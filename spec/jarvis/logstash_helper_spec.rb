require "jarvis/logstash_helper"
require 'tempfile'

describe Jarvis::LogstashHelper do
  context "download no-op" do
    it "should return version as is (LOGSTASH_PATH=true/false)" do
      expect( described_class.download_and_extract_gems_if_necessary('true') ).to eql 'true'
      expect( described_class.download_and_extract_gems_if_necessary('false') ).to eql 'false'
    end
    it "should return version as is (LOGSTASH_PATH=)" do
      expect( described_class.download_and_extract_gems_if_necessary('') ).to eql ''
      expect( described_class.download_and_extract_gems_if_necessary(nil) ).to eql nil
    end

    it "should not download and extract wout PREFIX@ (LOGSTASH_PATH=7.5.0)" do
      expect( described_class.download_and_extract_gems_if_necessary('7.5.0') ).to eql '7.5.0'
    end
  end

  let(:tmpfile) { Tempfile.new }
  let(:tmpdir) { Dir.mktmpdir }
  after { tmpfile.close }

  context "exact download version" do

    it "should download and extract (LOGSTASH_PATH=RELEASE@7.5.0)" do
      expect( Down ).to receive(:download).
          with('https://artifacts.elastic.co/downloads/logstash/logstash-7.5.0.tar.gz').and_return(tmpfile)
      expect( Jarvis ).to receive(:execute).
          with("tar -zxvf #{tmpfile.path} logstash-7.5.0/logstash-core-plugin-api logstash-7.5.0/logstash-core", anything)
      expect( described_class.download_and_extract_gems_if_necessary('RELEASE@7.5.0') ).to match /.*?\/logstash\-7\.5\.0/
      # /tmp/d20200203-1954-1el50b3/logstash-7.5.1
    end
  end

  context "loose download version" do
    let(:releases_json_file) { File.open(File.expand_path('../../fixtures/logstash_releases.json', __FILE__)) }

    it "should download and extract (LOGSTASH_PATH=RELEASE@latest)" do
      expect( Down ).to receive(:download).
          with('https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json').and_return(releases_json_file)
      expect( Down ).to receive(:download).
          with('https://artifacts.elastic.co/downloads/logstash/logstash-7.5.1.tar.gz').and_return(tmpfile)
      expect( Jarvis ).to receive(:execute).
          with("tar -zxvf #{tmpfile.path} logstash-7.5.1/logstash-core-plugin-api logstash-7.5.1/logstash-core", anything)
      expect( described_class.download_and_extract_gems_if_necessary('RELEASE@latest') ).to match /.*?\/logstash\-7\.5\.1/
    end

    it "should download and extract (LOGSTASH_PATH=release@6.x)" do
      expect( Down ).to receive(:download).
          with('https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json').and_return(releases_json_file)
      expect( Down ).to receive(:download).
          with('https://artifacts.elastic.co/downloads/logstash/logstash-6.8.6.tar.gz').and_return(tmpfile)
      expect( Jarvis ).to receive(:execute).
          with("tar -zxvf #{tmpfile.path} logstash-6.8.6/logstash-core-plugin-api logstash-6.8.6/logstash-core", anything)
      expect( described_class.download_and_extract_gems_if_necessary('release@6.x') ).to match /.*?\/logstash\-6\.8\.6/
    end

    it "should fail to download unknown release (LOGSTASH_PATH=RELEASE@1.x)" do
      expect( Down ).to receive(:download).
          with('https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json').and_return(releases_json_file)
      expect { described_class.download_and_extract_gems_if_necessary('RELEASE@1.x') }.
          to raise_error(Jarvis::LogstashHelper::UnresolvedLogstashVersion)
    end

    it "should fail to download unknown snapshot (LOGSTASH_PATH=SNAPSHOT@3.x)" do
      expect( Down ).to receive(:download).
          with('https://raw.githubusercontent.com/elastic/logstash/master/ci/logstash_releases.json').and_return(releases_json_file)
      expect { described_class.download_and_extract_gems_if_necessary('SNAPSHOT@3.x') }.
          to raise_error(Jarvis::LogstashHelper::UnresolvedLogstashVersion)
    end
  end
end