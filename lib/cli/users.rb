# frozen_string_literal: true

module CLI
  class Users < Base
    summary("Create and manage users")

    desc("create NAME", "Create a user, printing the password if one isn't given")
    option(:level, desc: "Level name or number, like admin or 40")
    option(:password, desc: "Generated if not given")
    option(:email, desc: "Required when email verification is enabled")
    option(:verified, type: :boolean, default: false, desc: "Mark the email as verified instead of sending a confirmation")
    def create(name)
      password = options[:password] || SecureRandom.alphanumeric(20)
      user = User.new(name: name, password: password, password_confirmation: password, email: options[:email])
      user.level = parse_level!(options[:level]) if options[:level]
      # same validation as signing up
      user.validate_email_format = true
      verify = Fennec.config.enable_email? && AdminConfig.instance.enable_email_verification? && !options[:verified]
      user.email_verified = !verify
      save!(user)
      say("Created #{user.name} (#{user.id}) as #{user.level_string}")
      if verify
        ::Users::EmailConfirmationMailer.confirmation(user).deliver_now
        say("Sent a confirmation email to #{user.email}")
      end
      say("Password: #{password}") unless options[:password]
    end

    desc("show NAME", "Show a user, by name or id")
    def show(name)
      user = find_user!(name)
      print_record(
        "ID"         => user.id,
        "Name"       => user.name,
        "Level"      => "#{user.level_string} (#{user.level})",
        "Email"      => user.email.presence || "none",
        "Verified"   => user.is_verified?,
        "Banned"     => user.is_banned?,
        "Created"    => user.created_at,
        "Last login" => user.last_logged_in_at || "never",
      )
    end

    desc("list", "List users, newest first")
    option(:level, desc: "Only users at this level")
    option(:limit, type: :numeric, default: 20)
    def list
      users = User.order(id: :desc).limit(options[:limit])
      users = users.where(level: parse_level!(options[:level])) if options[:level]
      print_table([%w[ID Name Level Created], *users.map { |u| [u.id, u.name, u.level_string, u.created_at.to_date] }])
    end

    desc("level NAME LEVEL", "Change a user's level")
    def level(name, level)
      user = find_user!(name)
      user.level = parse_level!(level)
      user.updater = actor
      user.is_admin_edit = true # logs the change
      save!(user)
      say("#{user.name} is now #{user.level_string}")
    end

    desc("password NAME", "Set a user's password, printing it if one isn't given")
    option(:password, desc: "Generated if not given")
    def password(name)
      user = find_user!(name)
      password = options[:password] || SecureRandom.alphanumeric(20)
      fail!("Password must be 6 to 128 characters") unless (6..128).cover?(password.length)
      user.upgrade_password(password)
      say("Password changed for #{user.name}")
      say("Password: #{password}") unless options[:password]
    end

    desc("rename NAME NEW_NAME", "Rename a user")
    def rename(name, new_name)
      user = find_user!(name)
      request = user.user_name_change_requests.create(original_name: user.name, desired_name: new_name, change_reason: "Administrative change", skip_limited_validation: true, creator: actor)
      fail!(request.errors.full_messages.join("; ")) unless request.valid?
      request.approve!(actor)
      say("Renamed #{name} to #{user.reload.name}")
    end

    desc("delete NAME", "Delete a user's account, the same as them deleting it themselves")
    option(:yes, type: :boolean, default: false, aliases: "-y", desc: "Don't ask for confirmation")
    def delete(name)
      user = find_user!(name)
      unless options[:yes] || ($stdin.tty? && yes?("Delete #{user.name} (#{user.id})? Their name, settings, email, and favorites are removed, and they can't log in. [y/N]"))
        fail!($stdin.tty? ? "Cancelled" : "Pass --yes to delete without a terminal")
      end
      UserDeletion.new(user, nil, nil, deleter: actor).delete!
      say("Deleted #{name}, now #{user.reload.name}")
    rescue UserDeletion::ValidationError => e
      fail!(e.message)
    end

    desc("ban NAME", "Ban a user")
    option(:reason, required: true)
    option(:duration, type: :numeric, desc: "In days, permanent if not given")
    def ban(name)
      user = find_user!(name)
      ban = Ban.new(user: user, reason: options[:reason], duration: options[:duration] || -1, creator: actor)
      save!(ban)
      say("Banned #{user.name} #{ban.expires_at ? "until #{ban.expires_at}" : 'permanently'}")
    end

    desc("unban NAME", "Unban a user")
    def unban(name)
      user = find_user!(name)
      fail!("#{user.name} isn't banned") unless user.is_banned?
      user.unban!(actor)
      say("Unbanned #{user.name}")
    end
  end
end
