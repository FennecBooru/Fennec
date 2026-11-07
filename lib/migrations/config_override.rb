# frozen_string_literal: true

module Migrations
  # Swaps the config model for a bare class while a migration runs, so it doesn't depend on the
  # current app code, e.g.:
  #
  #   before { admin_config_override! }
  #   after { AdminConfig.delete_cache }
  module ConfigOverride
    def config_override!(table = "config", model = :Config)
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
          # the migration probably changed its columns, or created/renamed/dropped the table
          reset_column_information
          return unless table_exists?
          Cache.delete(cache_key)
          Cache.delete("#{cache_key}:hash_columns")
        end
      end
      unless config_originals.key?(model)
        config_originals[model] = (Object.const_get(model) if Object.const_defined?(model, false))
      end
      replace_const(model, klass)
      klass
    end

    def admin_config_override!
      config_override!("admin_config", :AdminConfig)
    end

    # wraps exec_migration, so after hooks still see the override
    def migrate(...)
      super
    ensure
      config_originals.each { |model, original| replace_const(model, original) }
      config_originals.each_value { |original| original&.reset_column_information }
      config_originals.clear
    end

    private

    def config_originals
      @config_originals ||= {}
    end

    def replace_const(model, value)
      Object.send(:remove_const, model) if Object.const_defined?(model, false)
      Object.const_set(model, value) unless value.nil?
    end
  end

  ActiveRecord::Migration.prepend(ConfigOverride)
end
