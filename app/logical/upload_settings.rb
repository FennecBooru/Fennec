# frozen_string_literal: true

class UploadSettings
  include(ActiveModel::Serializers::JSON)

  ATTRIBUTES = %i[compact_mode safe_site post_tags character_groups_enabled character_groups upload_tags recent_tags allow_locked_tags allow_rating_lock allow_upload_as_pending allow_upload_as_in_progress max_file_size max_file_size_map max_file_size_per_request wiki_enabled layout minimum_tags].freeze

  attr_accessor(:user, :post)

  def initialize(user, post = nil)
    @user = user
    @post = post
  end

  def compact_mode
    user.compact_uploader?
  end

  def safe_site
    user.safe_mode?
  end

  # The plain "general tags" box: everything not attributed to a character group.
  def post_tags
    return if post.nil?
    tags = character_groups_enabled ? post.ungrouped_tags : post.tag_array
    "#{tags.sort.join(' ')} "
  end

  def character_groups_enabled
    Feature.enabled?(:character_groups)
  end

  def character_groups
    return [] if post.nil? || !character_groups_enabled
    post.character_groups_for_api
  end

  def upload_tags
    user.presenter.favorite_tags_with_types
  end

  def recent_tags
    user.presenter.recent_tags_with_types
  end

  def allow_locked_tags
    user.policy_for(Upload).can_use_attribute?(:locked_tags)
  end

  def allow_rating_lock
    user.policy_for(Upload).can_use_attribute?(:locked_rating)
  end

  def allow_upload_as_pending
    user.policy_for(Upload).can_use_attribute?(:as_pending)
  end

  def allow_upload_as_in_progress
    user.policy_for(Upload).can_use_attribute?(:as_in_progress)
  end

  def max_file_size
    AdminConfig.instance.max_file_size * 1.megabyte
  end

  def max_file_size_map
    AdminConfig.instance.max_file_sizes.transform_values { |v| v * 1.megabyte }
  end

  def max_file_size_per_request
    AdminConfig.instance.max_upload_per_request * 1.megabyte
  end

  def wiki_enabled
    Feature.enabled?(:wiki)
  end

  # The enabled sections in order, see UploaderSection.layout. Hints are rendered here since their links depend on
  # things like whether the wiki is enabled
  def layout
    sections = UploaderSection.layout
    sections = sections.reject { |section| section[:kind].in?(%w[rating lock_rating]) } unless Feature.enabled?(:ratings)
    # an array instead of a hash when there's nothing to parse
    hints = DTextHelper.bulk_parse(sections.pluck(:hint).compact_blank.uniq).presence || {}
    sections.map do |section|
      section.merge(
        hint:        hints.dig(section[:hint], :dtext) || "",
        placeholder: section[:placeholder].present? ? "Ex: #{section[:placeholder]}" : "",
      )
    end
  end

  def minimum_tags
    AdminConfig.instance.uploader_minimum_tags
  end

  def serializable_hash(*)
    { user_id: user.id }.merge(ATTRIBUTES.index_with { |attr| send(attr) })
  end
end
