# frozen_string_literal: true

class AdminConfig < ApplicationRecord
  self.table_name = "admin_config"
  validate(:validate_singleton_instance, on: :create)
  before_update(:log_update)
  after_update(-> { AdminConfig.delete_cache })
  after_update_commit(:enqueue_update_jobs)
  resolvable(:updater)

  # changing any of these runs AdminConfigUpdateJob with the new value
  UPDATE_JOB_OPTIONS = %i[enable_post_approvals enable_replacement_approvals enable_post_appeals].freeze

  def enqueue_update_jobs
    saved_changes.slice(*UPDATE_JOB_OPTIONS.map(&:to_s)).each do |name, (_old, value)|
      AdminConfigUpdateJob.perform_later(name, value)
    end
  end

  def validate_singleton_instance
    errors.add(:base, "Only one config record per instance is allowed") if AdminConfig.exists?(id: AdminConfig.config_id)
  end

  def log_update
    data = changes
    data.delete("updated_at")
    return if data.empty?
    log = StaffAuditLog.log!(updater, :config_update, data: data)
    if log.errors.any?
      Rails.logger.debug(log.errors.full_messages.inspect)
    end
  end

  def self.bypass?(option, user)
    return false unless column_names.include?("#{option}_bypass")
    user.level >= instance.public_send("#{option}_bypass")
  end

  def self.get(option)
    v = instance.public_send(option)
    return Float::INFINITY if v == -1
    return v.with_open_access if v.is_a?(Hash)
    v
  end

  # Admin config options are normally edited through the admin UI and stored in the `admin_config`
  # table, but any of them can be pinned to a fixed value via GAYFURCITY_ADMIN_CONFIG_<NAME>
  # (e.g. GAYFURCITY_ADMIN_CONFIG_ENABLE_SIGNUPS=false). A pinned option always wins over the
  # stored value and can no longer be edited in the UI - see settable_columns.
  def self.env_override_name(column)
    "#{GayFurCity::Config.env_name}_ADMIN_CONFIG_#{column.to_s.upcase}"
  end

  def self.env_override?(column)
    return false if %w[id updated_at].include?(column.to_s)
    ENV.key?(env_override_name(column))
  end

  def self.env_override(column)
    cast_env_value(column, ENV.fetch(env_override_name(column)))
  end

  def self.cast_env_value(column, raw)
    case columns_hash[column.to_s]&.type
    when :integer
      raw.to_i
    when :boolean
      raw.truthy?
    when :jsonb, :json
      JSON.parse(raw)
    else
      raw
    end
  end

  def self.env_overridden_columns
    column_names.select { |c| env_override?(c) }
  end

  def self.get_user(option, user)
    value = get(option)
    return nil if value.blank?
    return value unless value.is_a?(Hash)
    v = value.transform_keys(&:to_i).select { |k,| k <= user.level }.max_by(&:first)&.second
    v = 0 unless v.is_a?(Numeric) # jsonb has no schema - guard against a corrupt/non-numeric stored value
    return Float::INFINITY if v == -1
    v
  end

  def self.user?(option, user)
    value = get(option)
    return false if value.blank?
    user&.level.to_i >= value
  end

  def self.get_with_bypass(option, user)
    return Float::INFINITY if bypass?(option, user)
    get_user(option, user)
  end

  def self.instance
    Cache.fetch(cache_key) do
      uncached
    end
  end

  # includes the columns, otherwise a row cached before a migration added one would be missing it
  def self.cache_key
    "admin_config:#{config_id}:#{Digest::MD5.hexdigest(column_names.join(','))}"
  end

  def self.hash_columns
    Cache.fetch("#{cache_key}:hash_columns") do
      columns_hash.select { |_k, v| %i[json jsonb].include?(v.type) }.keys
    end
  end

  def self.values_for_hash_column(name)
    # the column won't exist yet when the app is loaded before its migration runs
    column_defaults[name.to_s]&.keys || []
  end

  # we technically could have a desync between model and hash columns, but I don't think that's
  # a big enough issue to care about
  def self.uncached
    find_or_create_by!(id: config_id)
  end

  def self.delete_cache
    Cache.delete(cache_key)
    Cache.delete("#{cache_key}:hash_columns")
  end

  def self.config_id
    GayFurCity.config.config_id
  end

  def self.settable_columns(_user)
    excluded = %w[id updated_at] + disabled_config_options + env_overridden_columns
    columns.reject { |c| excluded.include?(c.name) }
  end

  def self.disabled_config_options
    list = GayFurCity.config.disabled_config_options
    list.each do |name|
      list << "#{name}_bypass" if column_names.include?("#{name}_bypass")
    end
    list
  end

  def self.usable?(user, attribute)
    settable_columns(user).map(&:name).include?(attribute.to_s) && policy(user).update? && policy(user).can_use_attribute?(attribute.to_sym, :update)
  end

  def self.has_bypass?(attribute)
    column_names.include?("#{attribute}_bypass")
  end

  def self.show_backtrace?(user)
    return true if Rails.env.development?
    value = get(:show_backtrace)
    value <= user&.level.to_i
  end

  def usable?(...)
    AdminConfig.usable?(...)
  end

  def ary(key)
    public_send(key).split(",").map(&:strip)
  end

  def safe_app_name
    app_name.gsub(/[^a-zA-Z0-9_-]/, "_")
  end

  def system_user_name=(value)
    User.system(update: false).admin_edit!(updater, updater_ip_addr, name: value) if updater.present?
    super
  end

  # Every read of a config value (instance readers, the AdminConfig.foo/foo? class methods below,
  # and get/get_user/bypass? above, which all funnel through instance.public_send) needs to see
  # the env override, so it's applied at the lowest level rather than at each call site.
  def _read_attribute(name, &)
    return self.class.env_override(name) if self.class.env_override?(name)
    super
  end

  # AdminConfig.foo / AdminConfig.foo? for every column
  def self.method_missing(name, *args, &)
    column = name.to_s.delete_suffix("?")
    return super unless args.empty? && column_names.include?(column)
    name.end_with?("?") ? !!get(column) : get(column)
  end

  def self.respond_to_missing?(name, include_private = false)
    column_names.include?(name.to_s.delete_suffix("?")) || super
  end

  class << self
    delegate(:safe_app_name, :ary, to: :instance)
  end
end
