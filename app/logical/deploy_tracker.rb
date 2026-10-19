# frozen_string_literal: true

# Adds audit log entries as the system user when the site's version changes, and when a migration or fix is run
module DeployTracker
  module_function

  singleton_class.attr_writer(:enabled)

  # off in tests unless a test turns it on, since the migration test reruns every migration
  def enabled?
    @enabled.nil? ? !Rails.env.test? : @enabled
  end

  def version!
    version = GayFurCity.config.version
    return if version.blank?
    previous = StaffAuditLog.where(action: "version_bump").order(id: :desc).first&.data&.dig("new_version")
    return if previous == version
    log!(:version_bump, old_version: previous, new_version: version)
  end

  def migration!(migration, direction)
    return if migration.version.blank? # migrations nested with revert/run
    log!(:migration_run, version: migration.version.to_s, name: migration.name, direction: direction.to_s)
  end

  def fix!(name)
    log!(:fix_run, name: name)
  end

  def log!(action, **data)
    return unless enabled?
    # runs inside migrations, so it can't use User.system or let a failure abort the migration's transaction
    StaffAuditLog.transaction(requires_new: true) do
      user_id = User.where(level: User::Levels::SYSTEM).pick(:id) if StaffAuditLog.table_exists?
      StaffAuditLog.create!(user_id: user_id, user_ip_addr: "127.0.0.1", action: action.to_s, values: { data: data }) if user_id
    end
  rescue StandardError => e
    Rails.logger.warn("DeployTracker: failed to log #{action}: #{e.message}")
  end
end
