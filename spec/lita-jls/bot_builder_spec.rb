require 'spec_helper'
require 'lita-jls/bot_builder'
require 'stud/temporary'
require 'semverly'

describe LitaJLS::BotBuilder do
  subject { LitaJLS::BotBuilder.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:config) { { :ruby_version => 'jruby-1.7.16' } }
  let(:logstash_gem_fixture) { File.join(File.dirname(__FILE__), '..', 'fixtures') }
  let(:bad_project) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'bad_project') }
  let(:project_with_version_file) { File.join(File.dirname(__FILE__), '..', 'fixtures', 'project_with_version_file') } 

  it 'returns true if the project is a gem' do
    expect(subject.is_gem?).to eq(true)
  end
  
  it 'returns false if its not a gem' do
    Stud::Temporary.directory do |tmp_dir|
      bot = LitaJLS::BotBuilder.new(tmp_dir)
      expect(bot.is_gem?).to eq(false)
    end
  end

  it 'return true if the gem is not blacklisted' do
    expect(subject.publishable?).to eq(true)
  end

  it 'doesnt allow to publish the logstash gem' do
    bot = LitaJLS::BotBuilder.new(logstash_gem_fixture)
    expect(bot.publishable?).to eq(false)
  end

  describe "#fetch_last_released_version" do
    it 'returns the last version of the specified gem' do
      VCR.use_cassette('fetch_version_of_logstash-output-s3') do
        expect(subject.fetch_last_released_version('logstash-output-s3')).to eq('0.1.1')
      end
    end

    it 'return nil if the packages doesnt exist' do
      VCR.use_cassette('gem_doesnt_exist') do
        expect(subject.fetch_last_released_version('123-this-doesnt-exist')).to eq(nil)
      end
    end
  end

  describe "#local_version" do
    # Default way of creating gem with bundler is to define the
    # version in a version.rb and require it in the gemspec.
    # the problem with that is Gem::Specification will execute the ruby file
    # it require the version rb in the current 
    it 'read the version.rb if the project have one' do
      bot = LitaJLS::BotBuilder.new(project_with_version_file)
      expect(bot.local_version.to_s).to eq('0.0.2')
    end
  end

  describe "#execute_command" do
    it 'return a failing status if the command cannot be run' do
      bot = LitaJLS::BotBuilder.new(bad_project)
      expect(bot.run_successfully?(bot.execute_command("sh -c 'exit 1'"))).to eq(false)
    end

    it 'return sucessful status if the command run correctly' do
      bot = LitaJLS::BotBuilder.new('../../')
      expect(bot.run_successfully?(bot.execute_command('bundle install'))).to eq(true)
    end
  end

  describe '#execute_command_with_ruby' do
    let(:bot) { LitaJLS::BotBuilder.new(bad_project, config) }
    it 'add the rvm prefix if local machine is running rvm' do
      allow(bot).to receive(:using_rvm?).and_return(true)

      expect(bot.execute_command_with_ruby("ls -l").cmd).to eq("rvm #{config[:ruby_version]} do ls -l")
    end

    it 'add doesnt add the rvm prefix if local machine is not running rvm or rbenv' do
      allow(bot).to receive(:using_rvm?).and_return(false)
      allow(bot).to receive(:using_rbenv?).and_return(false)

      expect(bot.execute_command_with_ruby("ls -l").cmd).to eq("ls -l")
    end

    it 'raise an exception if we detect rbenv' do
      # this is not currently supported
      allow(bot).to receive(:using_rvm?).and_return(false)
      allow(bot).to receive(:using_rbenv?).and_return(true)

      expect{ bot.execute_command_with_ruby("ls -l") }.to raise_error(LitaJLS::BotBuilder::ConfigurationError)
    end
  end

  describe "#build", :network => true do
    let!(:test_opsbots_path) { File.expand_path(File.join(File.dirname(__FILE__), '..', 'fixtures', 'test-opsbots')) }
    let(:tasks_order) {
      ['bundle install',
       'bundle exec rake vendor',
        'bundle exec rspec']
    }
    let(:bot) do
      LitaJLS::BotBuilder.new(test_opsbots_path, config.merge({ :tasks_order => tasks_order }))
    end

    before do
      if File.directory?(test_opsbots_path)
        system("git --work-tree=#{test_opsbots_path} --git-dir=#{File.join(test_opsbots_path, '.git')} pull --ff-only origin master")
      else
        system("git clone git@github.com:ph/test-opsbots.git #{test_opsbots_path}")
      end
    end

    it 'should build the project if the local version of the gem is higher than the remote' do
      allow(bot).to receive(:local_version).and_return(SemVer.new(0, 0, 2))
      allow(bot).to receive(:rubygems_version).and_return(SemVer.new(0, 0, 1), SemVer.new(0, 0, 1), SemVer.new(0, 0, 2))

      results = bot.build

      expect(results[0].message).to match(/#{tasks_order[0]}/)
      expect(results[0].status).to eq(:ok)
      expect(results[1].message).to match(/#{tasks_order[1]}/)
      expect(results[1].status).to eq(:ok)
      expect(results[2].message).to match(/#{tasks_order[2]}/)
      expect(results[2].status).to eq(:ok)
      expect(results[3].message).to match(/^version on rubygems match local version/)
      expect(results[3].status).to eq(:ok)
    end

    it 'doesnt publish if the gem is the same version locally and on rubygems' do
      allow(bot).to receive(:local_version).and_return(SemVer.new(0, 0, 1))
      allow(bot).to receive(:rubygems_version).and_return(SemVer.new(0, 0, 1))

      results = bot.build
      expect(results.size).to eq(1)
      expect(results[0].status).to eq(:error)
      expect(results[0].message).to match(/^Local version and rubygems version are the same/)
    end

    it 'doesnt build if the project doesnt have a gemspec' do
      Stud::Temporary.directory do |tmp_dir|
        bot = LitaJLS::BotBuilder.new(tmp_dir, config.merge({ :tasks_order => ['bundle install',
                                                                               'bundle exec rake vendor',
                                                                               'bundle exec rspec'] }))

        results = bot.build
        expect(results.size).to eq(1)
        expect(results[0].status).to eq(:error)
        expect(results[0].message).to match(/doesn't have a gemspec$/)
      end
    end

    it 'should read the specification file' do
      repository = File.expand_path('spec/fixtures/logstash-codec-edn')
      bot = LitaJLS::BotBuilder.new(repository)
      expect(bot.gem_specification.version).to eq('0.1.3')
    end
  end
end
