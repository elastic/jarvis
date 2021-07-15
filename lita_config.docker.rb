# encoding: utf-8

# Configuration template, usable for production.
# @note used during the Docker image generation
Lita.configure do |config|
  config.robot.name = "Jarvis"
  config.robot.locale = :en
  config.robot.log_level = :info

  config.handlers.jarvis.cla_url = ""
  config.handlers.jarvis.github_token = ENV['GITHUB_TOKEN']
  config.http.host = "127.0.0.1"

  config.robot.adapter = :slack
  config.adapters.slack.token = ENV['SLACK_TOKEN']

  # For pushing to rubygems.org ENV['GEM_HOST_API_KEY'] is also required
end
