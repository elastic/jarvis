module LitaJLS
  class GithubUrlParser
    attr_reader :user, :project, :pr, :url

    URL_BASE = "https://github.com"

    def initialize(git_url, options)
      @url = git_url
      full_path = URI.parse(@url).path
      _, @user, @project, _, @pr = full_path.split('/')

      @options = { :link => :repository }.merge(options)
    end

    def valid_url?
      url =~ /^#{URL_BASE.gsub('/', '\/')}/
    end

    def validate_repository!
      if user.nil? || project.nil? || !valid_url?
        raise "Invalid URL. Expected something like: #{URL_BASE}/elasticsearch/snacktime/"
      end
    end

    def validate_pull_request!
      if user.nil? || project.nil? || pr.nil? || !valid_url?
        raise "Invalid URL. Expected something like: #{URL_BASE}/elasticsearch/snacktime/pull/12345"
      end
    end

    def validate!
      send("validate_#{@options[:link]}!")
    end

    def self.parse(git_url, options = {})
      new(git_url, options)
    end

    def git_url
      "#{URL_BASE}/#{user}/#{project}"
    end
  end
end
