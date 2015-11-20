require "jarvis/error"

module Jarvis module GitHub class PullRequest
  class InvalidURL < ::Jarvis::Error; end
  BASE_URL = "https://github.com"

  def self.parse(url)
    url = URI.parse(url) if url.is_a?(String)

    pr = self.new
    _, pr.organization, pr.project, type, pr.number, *remaining = url.path.split("/")
    if type != "pull" || remaining.any? || pr.organization.nil? || pr.project.nil? || pr.number.nil? || pr.number !~ /^\d+$/
      raise InvalidURL, "Not a valid GitHub pull request URL: #{url}"
    end
    pr
  end

  attr_accessor :organization, :project, :number

  def to_s
    "https://github.com/#{organization}/#{project}/pull/#{number}"
  end

  def repository_url
    [BASE_URL, organization, project].join("/")
  end

  def git_url
    #repository_url + ".git"
    "git@github.com:/#{organization}/#{project}.git"
  end

  def patch_url
    to_s + ".patch"
  end
end end end
