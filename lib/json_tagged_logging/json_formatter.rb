module JSONTaggedLogging
  # A custom formatter to print the log output as a JSON string.
  class JSONFormatter < ActiveSupport::Logger::SimpleFormatter
    TAG_EXTRACTION_RE = /([\.\w]+)=([^\s]*)\s?/
    TAG_EXTRACTION_CHECK_RE = /\A(#{TAG_EXTRACTION_RE})+\Z/

    def initialize(level: true, severity: level, timestamp: false, progname: false, **options)
      @severity = severity || level
      @timestamp = timestamp
      @progname = progname
    end

    def call(severity, timestamp, progname, msg)
      log = {}
      log[:level] = severity if @severity
      log[:timestamp] = timestamp if @timestamp
      log[:progname] = progname if @progname

      case msg
      when Hash
        # Hoist Hash tags from the tags array and
        # into the log Hash.
        if msg[:tags]&.respond_to?(:delete_if)
          log[:tags] = msg.delete(:tags)
          log[:tags].delete_if { |tag|
            tag = hashify_tag(tag)
            log.deep_merge!(tag) if Hash === tag
          }
          log.delete(:tags) if log[:tags].empty?
        end

        log.deep_merge!(msg)
      else log[:message] = msg
      end

      log.to_json + "\n"
    end

    def hashify_tag(tag)
      if String === tag && tag =~ TAG_EXTRACTION_CHECK_RE
        tag_hash = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
        tag.scan(TAG_EXTRACTION_RE).each do |k, v|
          # Convert dotted notation to nested Hash
          if k.index(".")
            tag_path = k.split(".")
            tag_hash.dig(*tag_path[0..-2])[tag_path.last] = v
          else
            tag_hash[k] = v
          end
        end
        tag_hash
      else
        tag
      end
    end
  end
end
