# encoding: utf-8

require 'lita'

# Start the bot locally using:
#
#   bundle exec lita start -c lita_config.dev.rb
#
Lita.configure do |config|
  config.robot.name = "Jarvis"
  config.robot.locale = :en
  config.robot.log_level = :info

  config.handlers.jarvis.cla_url = ""
  # Generate at https://github.com/settings/tokens
  # Will need the 'repo' scope and all sub-perms added
  config.handlers.jarvis.github_token = ENV['GITHUB_TOKEN'] || ''
  config.http.host = "127.0.0.1"

  if ENV["SLACK_TOKEN"]
    require 'lita-slack'
    # Go to https://my.slack.com/services/new/bot and make a new bot
    # You will interact directly via slack
    config.robot.adapter = :slack
    config.adapters.slack.token = ENV["SLACK_TOKEN"]
  else
    config.robot.adapter = :shell
  end
end
