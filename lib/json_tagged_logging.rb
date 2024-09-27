# frozen_string_literal: true

require "active_support"
require_relative "json_tagged_logging/version"
require_relative "json_tagged_logging/activesupport_patch"
require_relative "json_tagged_logging/json_formatter"
require_relative "json_tagged_logging/railtie"

# = JSON Tagged Logging for Rails
#
# Usage:
#
#    logger = JSONTaggedLogging.new(
#      ActiveSupport::Logger.new(STDOUT)
#    )
#
#    logger.tagged("MyTag").info("Hello World")
#    logger.tagged(user: "John", action: "create").info("Hello World")
#
module JSONTaggedLogging
  # An extension applied to a log formatter to present the log message as a
  # Hash with the appropriate tags.
  module Formatter
    def call(severity, timestamp, progname, msg)
      msg = current_tags.empty? ? msg : Hash.new.tap do |json|
        json[:tags] = current_tags.dup
        case msg
        when Hash then json.merge!(msg)
        else json[:message] = msg
        end
      end
      super(severity, timestamp, progname, msg)
    end
  end

  def self.new(logger)
    logger = logger.clone
    logger.formatter ||= JSONFormatter.new
    ActiveSupport::TaggedLogging.new(logger).tap do |tagged_logger|
      tagged_logger.extend(JSONTaggedLogging)
      tagged_logger.formatter.extend(Formatter)
    end
  end

  def tagged(*tags)
    if block_given?
      super
    else
      super(*tags).tap do |logger|
        logger.extend(JSONTaggedLogging)
        logger.formatter.extend(Formatter)
      end
    end
  end

end
