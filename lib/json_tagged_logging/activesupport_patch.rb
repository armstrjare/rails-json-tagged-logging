module ActiveSupport::TaggedLogging::Formatter
  alias _call call

  # The ActiveSupport::TaggedLogging implementation prepends the
  # tags to the Formatter call as a String (and converts the msg
  # to a String too). We monkey-patch the implementation to call
  # our own handler instead to be able to handle Hash messages
  # as well as including the tags in a Hash.
  def call(severity, timestamp, progname, msg)
    case self
    when JSONTaggedLogging::Formatter
      super
    else
      _call(severity, timestamp, progname, msg)
    end
  end
end
