# frozen_string_literal: true

class TagFollowerUpdateJob < ApplicationJob
  queue_as(:followers)

  def perform(post_id)
    # may have been queued before following was disabled
    return unless Feature.enabled?(:tag_following)
    post = Post.find(post_id)
    TagFollower.update_from_post!(post)
  end
end
