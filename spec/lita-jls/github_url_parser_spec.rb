require 'spec_helper'
require 'lita-jls/github_url_parser'

describe LitaJLS::GithubUrlParser do
  subject { LitaJLS::GithubUrlParser }

  context 'when the url is a repository' do
    let(:url) { 'https://github.com/elasticsearch/logstash' }
    let(:parser) { subject.parse(url) }

    it 'extract the different parts of the url' do
      expect(parser.user).to eq('elasticsearch')
      expect(parser.project).to eq('logstash')
      expect(parser.pr).to eq(nil)
    end

    it 'returns the git url of the repository' do
      expect(parser.git_url).to eq('https://github.com/elasticsearch/logstash')
    end

    it 'should validates the presence of #url, #project and valid github url' do
      expect { parser.validate! }.not_to raise_error
    end


    it 'raise an exception if the domain is not on github' do
      subject.parse('http://gitlab/blah/test')
      expect { subject.validate! }.to raise_error
    end
    
    it 'raise an exception if it cannot extract the user' do
      subject.parse('http://github.com/')
      expect { subject.validate! }.to raise_error
    end

    it 'raise an exception if it cannot extract the project' do
      subject.parse('http://github.com/elasticsearch')
      expect { subject.validate! }.to raise_error
    end
  end

  context 'when the url is pull request' do
    let(:url) { 'https://github.com/elasticsearch/logstash/pull/2' }
    let(:parser) { subject.parse(url, { :link => :pull_request }) }

    it 'extract the different parts of the url' do
      expect(parser.user).to eq('elasticsearch')
      expect(parser.project).to eq('logstash')
      expect(parser.pr).to eq('2')
    end

    it 'returns the git url of the repository' do
      expect(parser.git_url).to eq('https://github.com/elasticsearch/logstash')
    end

    it 'should validates the presence of #url, #project, #pr and valid github url' do
      expect { parser.validate! }.not_to raise_error
    end

    it 'raise an exception if the domain is not on github' do
      subject.parse('http://gitlab/blah/test/pull/2', { :link => :pull_request })
      expect { subject.validate! }.to raise_error
    end

    it 'raise an exception if it cannot extract the user' do
      subject.parse('http://github.com/', { :link => :pull_request })
      expect { subject.validate! }.to raise_error
    end

    it 'raise an exception if it cannot extract the project' do
      subject.parse('http://github.com/elasticsearch',  { :link => :pull_request })
      expect { subject.validate! }.to raise_error
    end

    it 'raise an exception if it cannot extract the pull request number' do
      subject.parse('http://github.com/elasticsearch/logstash/pull/',  { :link => :pull_request })
      expect { subject.validate! }.to raise_error
    end
  end
end
