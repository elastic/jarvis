Lita.configure do |config|
  config.robot.name = "Jarvis"
  config.robot.locale = :en
  config.robot.log_level = :info

  config.handlers.jarvis.cla_url = ""
  # Generate at https://github.com/settings/tokens
  # Will need the 'repo' scope and all sub-perms added
  config.handlers.jarvis.github_token = ""
  config.http.host = "127.0.0.1"

  config.robot.adapter = :slack
  # Go to https://my.slack.com/services/new/bot and make a new bot
  # You will interact directly via slack
  config.adapters.slack.token = ""
end
