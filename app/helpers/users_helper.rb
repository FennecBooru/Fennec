# frozen_string_literal: true

module UsersHelper
  def email_sig(user, purpose, expires = nil)
    EmailLinkValidator.generate(user.id.to_s, purpose, expires)
  end

  def email_domain_search(email)
    return unless email.to_s.include?("@")

    domain = email.split("@").last
    link_to("»", users_path(search: { email_matches: "*@#{domain}" }))
  end

  # A level's name, colored like usernames are. Accepts an id, or a name like "Former Staff" or "former_staff"
  def user_level(level)
    level = User::Levels.name_to_id(level.to_s.parameterize(separator: "_")) unless level.is_a?(Integer)
    return "" if level.nil?
    name = User::Levels.id_to_name(level)
    tag.span(name, class: "with-style #{User::Levels.level_class(name)}")
  end

  def user_levels_for_select(min_level = User::Levels::MEMBER, max_level = User::Levels::OWNER, current: nil)
    User::Levels.hash.select do |_name, level|
      within_range = level >= min_level && (max_level.nil? || level <= max_level)
      is_current   = current && current == level
      within_range || is_current
    end
  end

  def user_level_select_tag(name, min_level = User::Levels::MEMBER, options = {}, current: nil)
    choices = [
      ["", ""],
      *user_levels_for_select(min_level, current: current),
    ]

    select_tag(name, options_for_select(choices, params[name].to_i), options)
  end

  def user_level_select(object, field, min_level = User::Levels::MEMBER)
    options = user_levels_for_select(min_level).to_a
    select(object, field, options)
  end
end
