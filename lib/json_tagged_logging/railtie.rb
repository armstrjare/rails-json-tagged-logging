require "rails/railtie"

module JSONTaggedLogging
  # Configure the backtrace silencer to ignore lines from this library.
  class Railtie < Rails::Railtie
    config.after_initialize do |app|
      Rails.backtrace_cleaner.add_silencer { |line| line.include?("json_tagged_logging") }
    end
  end
end
