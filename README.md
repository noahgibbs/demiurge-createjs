# Demiurge-Createjs

Demiurge-Createjs provides Websocket-based transport using the Faye
library and CreateJS-based display for HTML games to use Demiurge.

Demiurge, in turn, is a library for easy creation of gamelike physics
and artificial intelligence using Ruby.

Relevant technologies used by Demiurge-Createjs include:

* Websockets and other browser publish/subscribe messages using Faye
* CreateJS
* CoffeeScript
* The Tiled Sprite Editor (TMX/TSX format)
* EventMachine for evented Ruby code

Demiurge is primarily intended for simulation-heavy games that don't
need fast realtime response. Demiurge-Createjs continues this trend
with extensible, debuggable transport formats based on JSON and easy
modularity and customization of interfaces. "Twitchy" action games
need to be sure everything happens with absolutely minimum latency.
Customization must be very limited or very fragile to avoid
compromising that goal. Demiurge attempts to provide easy content
creation and enjoyable programming interfaces, which limits its
performance and latency.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'demiurge-createjs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install demiurge-createjs

## Usage

Ordinarily you'll use Demiurge-Createjs by creating a piece of
software, such as a game, that uses it. Add the demiurge-createjs gem
to your application's Gemfile or gemspec and run "bundle" to install.

This gem includes a sample config.ru file, showing how to serve the
appropriate HTML and JavaScript content for your browser-based game
client and to connect your evented game server via websockets.

Your software will run via an app server, either Thin or Puma.

    $ thin start -R config.ru -p 3001

## Development

After checking out the repo, run `bin/setup` to install
dependencies. Then, run `rake test` to run the tests. You can also run
`bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake
install`. To release a new version, update the version number in
`version.rb`, and then run `bundle exec rake release`, which will
create a git tag for the version, push git commits and tags, and push
the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/[USERNAME]/demiurge-createjs. This project is
intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor
Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT
License](http://opensource.org/licenses/MIT).
