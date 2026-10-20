# frozen_string_literal: true

class SystemInfo
  # Read only listing of Fennec::Config, with secrets hidden
  class ConfigOptions
    SECRET = /secret|password|token|webhook|key\z/
    HIDDEN = "[hidden]"

    Option = Struct.new(:name, :value, :source, :state, keyword_init: true) do
      def secret?
        state == :secret
      end
    end

    attr_reader(:options)

    def initialize
      @options = []
    end

    def load
      @options = Fennec::Config.list.map { |name| build(name) }
      self
    end

    private

    def config
      Fennec.config
    end

    def build(name)
      method = config.method(name)
      source = source_for(name, method)
      if takes_arguments?(name, method)
        Option.new(name: name, source: source, state: :arguments)
      else
        value = config.public_send(name)
        if name.to_s.match?(SECRET) && value.present?
          Option.new(name: name, value: HIDDEN, source: source, state: :secret)
        else
          Option.new(name: name, value: value.is_a?(String) ? hide_url_password(value) : value, source: source, state: :value)
        end
      end
    # options without a default, and required! ones, raise NotImplementedError when they aren't set
    rescue NotImplementedError
      Option.new(name: name, value: nil, source: source, state: :value)
    rescue StandardError => e
      Option.new(name: name, value: e.message, source: source, state: :error)
    end

    # local and config.d files override options by redefining the method
    def source_for(name, method)
      file = method.source_location&.first
      return Pathname.new(file).relative_path_from(Rails.root).to_s if file && file != builder_file
      return "#{Fennec::Config.env_name}_#{name.to_s.upcase}" if Fennec::Config.env_set[name] && config.env(name).present?
      "default"
    end

    def builder_file
      @builder_file ||= YiffSpace::Config::Builder.instance_method(:env_or_value).source_location.first
    end

    def takes_arguments?(name, method)
      return Fennec::Config.argument_options.include?(name) if method.source_location&.first == builder_file
      method.parameters.any? { |type, _| %i[req opt].include?(type) }
    end

    def hide_url_password(value)
      value.sub(%r{\A([a-z][a-z0-9+.-]*://[^:/@\s]*:)[^@/\s]+@}i, "\\1#{HIDDEN}@")
    end
  end
end
