require "jarvis/error"

module Jarvis module GitHub class Project
  class InvalidURL < ::Jarvis::Error; end
  def self.parse(url)
    uri = URI.parse(url)
    _, organization, name, *_ = uri.path.split("/")
    if organization.nil?
      raise InvalidURL, "Could not find the organization in the url"
    end
    if name.nil?
      raise InvalidURL, "Could not find the name in the url"
    end
    return self.new(organization, name)
  end

  attr_reader :organization, :name

  def initialize(organization, name)
    @organization = organization
    @name = name
  end

  def git_url
    return "https://github.com/#{@organization}/#{@name}"
  end
end end end
