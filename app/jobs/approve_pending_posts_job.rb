# frozen_string_literal: true

# approves the queue when post approvals are turned off, since nothing could approve it otherwise
class ApprovePendingPostsJob < ApplicationJob
  queue_as(:default)

  def perform
    # approvals may have been turned back on before this ran
    return if AdminConfig.enable_post_approvals?
    Post.pending.where(is_deleted: false).find_each { |post| post.approve!(User.system) }
  end
end
