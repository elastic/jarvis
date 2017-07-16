require "jarvis/error"
require "faraday"
require "faraday_middleware"

module Jarvis module Fetch
  class DownloadFailure < ::Jarvis::Error; end
  def self.file(url)
    url = URI.parse(url) if url.is_a?(String)
    file = Stud::Temporary.file

    # TODO(sissel): timeout + retry
    http = Faraday.new do |conn|
      conn.use FaradayMiddleware::FollowRedirects
      conn.adapter :net_http
    end

    response = http.get(url)

    if response.status != 200
      raise DownloadFailure, "Got HTTP #{response.status} when fetching #{url}"
    end

    file.write(response.body.force_encoding('utf-8'))
    file.flush
    file.rewind

    file
  end
end end
