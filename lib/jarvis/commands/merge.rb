require "clamp"
require "i18n"

module Jarvis module Command class Merge < Clamp::Command

  banner "Merge a pull request into one or more branches."

  parameter "URL", "The URL to merge"
  parameter "BRANCHES ...", "The branches to merge"

  def execute
    puts "Merging: #{url} into #{branches_list}"
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge")
  end
end end end
