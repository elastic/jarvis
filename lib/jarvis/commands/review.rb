require "clamp"
require "i18n"
require 'uri'

module Jarvis module Command class Review < Clamp::Command
  include ::Jarvis::Github

  banner "Ask for a review of a PR"

  parameter "URL", "The URL to review", :required => false
  
  def pr
    @pr ||= Jarvis::GitHub::PullRequest.parse(url)
  end

  # Note, this is the creds of whatever token you set. When developing
  # it's probably your personal account!
  def gh_botname
    @gh_botname ||= github.user.login
  end

  def assign_issue
    res = github.update_issue("#{pr.organization}/#{pr.project}", pr.number, {:assignees => ['elasticsearch-bot']})
  end

  def execute
    # Search for items to show 
    total, items = Jarvis::Github::ReviewSearch.execute

    if url # If we've been asked to assign an issue
      res = assign_issue
      issue_user = res[:user][:login]
      items = items.select {|item| item[:user][:login] != issue_user }
      needs_reviewing = items.empty? ? "I don't have anything to recommend you to review right now" :
                                       "Say, would you remind reviewing one of these PRs?"
      puts "Thanks for submitting this issue for review! #{needs_reviewing}"
    else
      puts "#{total} PRs need reviews"
    end
    
    formatted = ::Jarvis::Github::ReviewSearch.format_items(items[0..10])
    formatted.each {|line| puts line}
  end
end; end; end
