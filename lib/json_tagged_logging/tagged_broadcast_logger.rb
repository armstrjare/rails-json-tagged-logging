module JSONTaggedLogging
  class TaggedBroadcastLogger < ActiveSupport::BroadcastLogger
    def tagged(*tags)
      if block_given?
        broadcasts.inject(proc { yield self }) do |block, logger|
          if logger.respond_to?(:tagged)
            proc { logger.tagged(*tags, &block) }
          else
            block
          end
        end.call
        self
      else
        loggers = broadcasts.map { |logger|
          logger.respond_to?(:tagged) ? logger.tagged(*tags) : logger
        }
        self.class.new.tap do |logger|
          logger.formatter = loggers.first&.formatter
          logger.broadcast_to(*loggers)
        end
      end
    end
  end
end
