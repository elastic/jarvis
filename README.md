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

## Contributing

Patches, ideas, and bug reports welcome. :)
