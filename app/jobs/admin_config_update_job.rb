# frozen_string_literal: true

# runs after an option in AdminConfig::UPDATE_JOB_OPTIONS changes, to act on its new value
class AdminConfigUpdateJob < ApplicationJob
  queue_as(:default)
  good_job_control_concurrency_with(perform_limit: 1, key: -> { "AdminConfigUpdateJob-#{arguments[0]}" })

  def perform(name, value)
    # the option may have been changed again before this ran
    return unless AdminConfig.instance.public_send(name) == value

    case name.to_sym
    when :enable_post_approvals
      approve_pending_posts unless value
    when :enable_replacement_approvals
      approve_pending_replacements unless value
    when :enable_post_appeals
      accept_pending_appeals unless value
    end
  end

  private

  # nothing could approve them otherwise
  def approve_pending_posts
    Post.pending.where(is_deleted: false).find_each { |post| post.approve!(User.system) }
  end

  # undeleting a post accepts its appeals. taken down or status locked posts aren't undeleted, so
  # their appeals are rejected instead of being left with nothing to handle them
  def accept_pending_appeals
    Post.where(id: PostAppeal.pending.select(:post_id)).find_each do |post|
      post.undelete!(User.system) if post.is_deleted? && !post.is_taken_down?
      post.appeals.pending.each { |appeal| post.is_deleted? ? appeal.reject!(User.system) : appeal.accept!(User.system) }
    rescue StandardError => e
      ExceptionLog.add!(e, source: "AdminConfigUpdateJob", args: { post_id: post.id })
    end
  end

  def approve_pending_replacements
    PostReplacement.pending.joins(:post).where(posts: { is_deleted: false }).order(:id).find_each do |replacement|
      replacement.approve!(User.system, penalize_current_uploader: false)
    rescue StandardError => e
      ExceptionLog.add!(e, source: "AdminConfigUpdateJob", args: { post_replacement_id: replacement.id })
    end
  end
end
