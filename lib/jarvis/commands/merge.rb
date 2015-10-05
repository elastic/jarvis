require "clamp"

module Jarvis module Command class Merge < Clamp::Command

  banner "Merge a pull request into one or more branches."

  parameter "URL", "The URL to merge"
  parameter "BRANCHES ...", "The branches to merge"

  def execute
    puts "Merging: #{url} into #{branches_list}"
  rescue => e
    puts "An error occurred: #{e.class} - #{e}\n" + e.backtrace.join("\n")
  end
end end end
