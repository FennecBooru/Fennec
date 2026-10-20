# frozen_string_literal: true

module Migrations
  module ConfigOverride
    extend(ActiveSupport::Concern)

    module ClassMethods
      def with_config_override!(table = "config", model = :Config)
        klass = Class.new(ApplicationRecord) do
          self.table_name = table

          def self.config_id
            Fennec.config.config_id
          end

          def self.get
            find_or_create_by!(id: config_id)
          end

          # the same as AdminConfig.cache_key
          def self.cache_key
            "admin_config:#{config_id}:#{Digest::MD5.hexdigest(column_names.join(','))}"
          end

          def self.delete_cache
            Cache.delete(cache_key)
            Cache.delete("#{cache_key}:hash_columns")
          end
        end
        return yield(klass) if block_given?
        # only swapped in while the migration runs, migrations are loaded well before then
        config_overrides[model] = klass
        klass
      end

      def with_admin_config_override!(&)
        with_config_override!("admin_config", :AdminConfig, &)
      end

      def config_overrides
        @config_overrides ||= {}
      end
    end

    def exec_migration(...)
      overrides = self.class.config_overrides
      return super if overrides.empty?

      originals = overrides.keys.index_with { |model| Object.const_get(model) if Object.const_defined?(model, false) }
      overrides.each { |model, klass| replace_const(model, klass) }
      begin
        super
      ensure
        originals.each { |model, original| replace_const(model, original) }
        # the migration probably changed its columns
        originals.each_value { |original| original.try(:reset_column_information) }
      end
    end

    private

    def replace_const(model, value)
      Object.send(:remove_const, model) if Object.const_defined?(model, false)
      Object.const_set(model, value) unless value.nil?
    end
  end

  ActiveRecord::Migration.prepend(ConfigOverride)
end
