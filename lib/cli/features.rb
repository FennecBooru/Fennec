# frozen_string_literal: true

module CLI
  class Features < Base
    summary("Turn site features on and off")

    desc("list", "List the features and whether they're enabled")
    def list
      print_table(Feature.definitions.map { |f| [f.name, Feature.enabled?(f.name) ? "enabled" : "disabled"] })
    end

    desc("enable NAME", "Enable a feature")
    def enable(name)
      toggle(name, true)
    end

    desc("disable NAME", "Disable a feature")
    def disable(name)
      toggle(name, false)
    end

    no_commands do
      def toggle(name, value)
        feature = Feature.find(name)
        invoke(CLI::Config, :set, [feature.column.to_s, value.to_s])
      rescue ArgumentError => e
        fail!(e.message)
      end
    end
  end
end
