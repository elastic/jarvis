# J.A.R.V.I.S.

Jarvis is a chatops bot used at Elastic.

## Developing

Jarvis is written in Ruby, so you'll need Ruby.

Once you've got Ruby, we can continue and install Jarvis' other dependencies:

* `gem install bundler`
* `bundle install`

You'll also need a Redis server running because Lita requires that for some
runtime storage/configuration. Simply running a local `redis-server` is
sufficient.

## Testing

* `bundle exec rspec`

## Running

* `bundle exec lita`

You'll probably want a `lita_config.rb` if you want to have this connect to
Slack. The following is an example lita configuration. Put this in a file
called `lita_config.rb` in your git clone of this repo. You'll need to edit it to add github, slack, and other credential information. 

DO NOT ADD THIS FILE TO GIT. It is too easy to accidentally commit credentials to git, and public git is not the right place to store credentials ;)

```ruby
# encoding: utf-8

Lita.configure do |config|
  config.robot.name = "Jarvis"
  config.robot.locale = :en
  config.robot.log_level = :info

  # Set a user+pass+host for cla check
  config.handlers.jarvis.cla_url = "http://user:password@clacheck.example.com/verify/pull_request"

  # You'll need to set this to be a github oauth token
  # Go to https://github.com/settings/tokens and click 'Generate new token'
  # button. This token will need private and public repo access (push, etc)
  config.handlers.jarvis.github_token = "your token"

  # Lita has a web service. We don't use it, but I don't know how to turn it
  # off, so this makes sure it just listens on localhost
  config.http.host = "127.0.0.1"

  config.robot.adapter = :slack

  # Update this with a slack token. You can create a bot user and token by
  # visiting https://my.slack.com/services/new/bot
  config.adapters.slack.token = "Your Slack Bot Token"
end
```

## Contributing

Patches, ideas, and bug reports welcome. :)
