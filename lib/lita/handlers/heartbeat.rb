require "securerandom"
require "concurrent"
require "stud/interval"
require "time"

module Lita
  module Handlers
    class Heartbeat < Handler
      route(/^ping\s*$/, :command => true) do |response|
        response.reply(t("ping response"))
      end

      Lita.register_handler(self)
    end
  end
end
