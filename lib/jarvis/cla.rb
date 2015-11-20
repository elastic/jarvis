require "json"
require "faraday"

module Jarvis class CLA
  def self.check(cla_url, repository, pr)
    cla_uri = URI.parse(cla_url)
    conn = Faraday.new(:url => "#{cla_uri.scheme}://#{cla_uri.host}")
    conn.basic_auth(cla_uri.user, cla_uri.password)
    response = conn.get(cla_uri.path, :repository => repository, :number => pr)
    check = JSON.parse(response.body)
    # TODO(sissel): json exception? .get exception?

    return self.new(check["status"] == "success", check["message"])
  end

  private
  def initialize(ok, message)
    @ok = ok
    @message = message
  end

  # The message indicating whatever reason for the success (or failed) CLA check
  attr_reader :message

  # Was this check successful?
  def ok?
    return @ok
  end

  public(:ok?, :message)
end end
