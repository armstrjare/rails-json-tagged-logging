# JsonTaggedLogging

Structured logging with JSON formatted output makes it easy to search and analyze logs. Frustratingly, ActiveSupport::TaggedLogging interferes with this by converting your log messages to a String which breaks structured logging.

This library adds an extension for ActiveSupport::TaggedLogging that allows
structured logging without interfering with standard Rails logging and tagging.

## Setup

Add the gem to your Gemfile:
```
gem 'json_tagged_logging', git: 'git://github.com/armstrjare/rails-json-tagged-logging.git'
```

In your `config/application.rb` file (or where you configure your logger), change
your Logger initializer to use `JsonTaggedLogging::TaggedLogging`.

```ruby
# Log with our JSON format
config.logger = ActiveSupport::Logger.new(log_device)
  .tap  { |logger| logger.formatter = JSONTaggedLogging::JSONFormatter.new }
  .then { |logger| JSONTaggedLogging.new(logger) }
```

If you want to output Rails logs with the standard format aswell (eg. in development), use
a ActiveSupport::Broadcast logger:

```ruby
if Rails.env.development?
  # Initialize BroadcastLogger
  config.logger = ActiveSupport::BroadcastLogger.new(config.logger).tap do |broadcast_logger|
    # ActiveSupport::BroadcastLogger does not set the formatter on initialization.
    # We need to set it manually because otherwise ActiveJob tagged logging will break.
    broadcast_logger.formatter = config.logger.formatter
  end

  # Broadcast to STDOUT with the standard formatter. This will look like your normal Rails logs
  # in development mode going to STDOUT.
  config.logger.broadcast_to ActiveSupport::Logger.new(STDOUT).then { |logger|
    ActiveSupport::TaggedLogging.new(logger)
  }
end
```

## Usage

```ruby
# A basic message will log JSON output with the message in the "message" field:
logger = JSONTaggedLogging.new(ActiveSupport::Logger.new(log_device))
logger.info "Hello, world!"
```
```json
{ "level": "INFO", "message": "Hello, world!" }
```

```ruby
# Adding `tagged` logs will add them to a `tags` array:
logger.tagged("ActiveJob").info "Hello, world!"
```
```json
{ "level": "INFO", "tags": ["ActiveJob"], "msg": "Hello, world!" }
```

There is also a special Formatter called `JSONTaggedLogging::JSONFormatter` that will:

1. Merge tags into the root of the JSON log entry when they are Hashes
2. Extract String notation tags like `dd.trace_id=abcdef` and add them to the JSON log entry as ```{ "dd": { "trace_id": "abcdef" } }```

```ruby
# To use this Formatter, set it as the formatter when initializing your logger:
logger = ActiveSupport::Logger.new(log_device).tap do |logger|
  logger.formatter = JSONTaggedLogging::JSONFormatter.new
end.then { |logger| JSONTaggedLogging.new(logger) }

# Using a Hash for tags merges them into the root of the JSON log entry:
logger.tagged("dd.trace_id=1234567890 dd.span_id=1234567890")
  .tagged("ActiveJob")
  .tagged(service: "Authentication")
  .tagged(usr: { id: 123, name: "Jared" })
  .info "Hello, world!"
```
```json
{ "level": "INFO",
  "tags": ["ActiveJob"],
  "dd": { "trace_id": "1234567890", "span_id": "1234567890" },
  "service": "Authentication",
  "usr": { "id": 123, "name": "Jared" },
  "message": "Hello, world!" }
```
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/json_tagged_logging.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
