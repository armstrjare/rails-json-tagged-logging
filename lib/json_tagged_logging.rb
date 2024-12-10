# frozen_string_literal: true

require "active_support"
require_relative "json_tagged_logging/version"
require_relative "json_tagged_logging/activesupport_patch"
require_relative "json_tagged_logging/json_formatter"
require_relative "json_tagged_logging/railtie"
require_relative "json_tagged_logging/tagged_broadcast_logger"

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
    def self.extended(formatter)
      # The TaggedLogging::Formatter module defines a `tags_text` method that allows you to
      # read the current tags as pre-formatted string prefix for an empty log message. There
      # is one place in the Rails codebase where this is used, in the strack trace
      # formatting when logging an exception, where it will prefix each stack trace line
      # with the traditionally formatted tags text. We don't want to use this method in the
      # JSON formatter, so we undefine it for the formatter instance.
      #
      # For reading the current tags, the `current_tags` method should be used.
      #
      # @see https://github.com/rails/rails/blob/v8.0.0/actionpack/lib/action_dispatch/middleware/debug_exceptions.rb#L177
      # @see https://github.com/rails/rails/blob/v8.0.0/activesupport/lib/active_support/tagged_logging.rb#L65
      class << formatter
        undef_method :tags_text
      end if formatter.respond_to?(:tags_text)
    end

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
