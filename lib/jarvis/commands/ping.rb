require "clamp"
require "i18n"

module Jarvis module Command class Ping < Clamp::Command
  def execute
    puts I18n.t("lita.handlers.jarvis.ping response")
  end
end end end
