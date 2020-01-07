require "jarvis/error"
require "down"

module Jarvis module Fetch
  DownloadError = ::Down::Error

  def self.file(url)
    url = URI.parse(url) if url.is_a?(String)

    file = Down.download(url.to_s) # Tempfile

    if block_given?
      begin
        yield(file)
      ensure
        file.close
      end
    else
      file.flush
      file.rewind
    end

    file
  end
end end
