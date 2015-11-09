require "clamp"
require "i18n"
require "git"

module Jarvis module Command class Merge < Clamp::Command

  banner "Merge a pull request into one or more branches."

  option "--committer", "COMMITTER", "The git committer to set on all commits. If not set, the default is whatever your git defaults to (see `git config --get user.name` and `git config --get user.email`)."

  parameter "URL", "The URL to merge"
  parameter "BRANCHES ...", "The branches to merge"

  def execute
    puts "This merge command does nothing, yet!"
    # Fetch the .patch
    # Clone the git repo
    # Merge the patch
    # Modify commit messages
    # Push to branches
    # Set labels on PRs
  rescue => e
    puts I18n.t("lita.handlers.jarvis.exception", :exception => e.class, :message => e.to_s, :stacktrace => e.backtrace.join("\n"), :command => "merge")
  end
end end end
