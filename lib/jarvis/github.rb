module Jarvis; module Github
  def self.client(github_token=nil)
    return @github if @github
    @github = Octokit::Client.new
    @github.access_token = github_token
    @github.login
    @github
  end

  def github
    ::Jarvis::Github.client
  end
end; end