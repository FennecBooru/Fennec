# frozen_string_literal: true

module Security
  class LockdownController < ApplicationController
    respond_to(:html)
    wrap_parameters(:lockdown)
    before_action(:block_apikey_authentication)

    def index
      authorize(%i[security lockdown])
    end

    def panic
      authorize(%i[security lockdown])
      Security::Lockdown::BOOLEAN_TYPES.each do |type|
        Security::Lockdown.public_send("#{type}_disabled=", true)
      end

      StaffAuditLog.log!(CurrentUser.user, :lockdown_panic)
      redirect_to(security_root_path)
    end

    def enact
      authorize(%i[security lockdown])
      params = permitted_attributes(%i[security lockdown])
      logparams = params.dup

      Security::Lockdown::BOOLEAN_TYPES.each do |type|
        next if params[type].blank?
        if Security::Lockdown.public_send("#{type}_disabled?") == params[type].to_s.truthy?
          logparams.delete(type)
          next
        end
        Security::Lockdown.public_send("#{type}_disabled=", params[type])
      end

      StaffAuditLog.log!(CurrentUser.user, :lockdown, params: logparams.transform_values { |v| v.to_s.truthy? })
      redirect_to(security_root_path)
    end

    def uploads_min_level
      authorize(%i[security lockdown])
      new_level = params.dig(:uploads_min_level, :min_level).to_i
      old_level = Lockdown.uploads_min_level
      return render_expected_error(422, "#{new_level} is not valid") unless User::VALID_LEVELS.include?(new_level)
      if new_level != old_level
        Security::Lockdown.uploads_min_level = new_level
        StaffAuditLog.log!(CurrentUser.user, :min_upload_level_change, old_level: old_level, new_level: new_level)
      end
      redirect_to(security_root_path)
    end

    def uploads_hide_pending
      authorize(%i[security lockdown])
      duration = params[:uploads_hide_pending][:duration].to_f
      if duration >= 0 && duration != Security::Lockdown.hide_pending_posts_for
        Security::Lockdown.hide_pending_posts_for = duration
        StaffAuditLog.log!(CurrentUser.user, :hide_pending_posts_for, duration: duration)
      end
      redirect_to(security_root_path)
    end
  end
end
