# frozen_string_literal: true

module Forums
  module Topics
    class MovesController < ApplicationController
      before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_forums? })
      respond_to(:html, :json)

      wrap_parameters(:forum_topic)

      def show
        @forum_topic = authorize(ForumTopic.find(params[:id]), :move?)
        @categories = ForumCategory.visible(CurrentUser.user).select { |cat| cat.can_create_within?(CurrentUser.user) && cat.can_create_within?(@forum_topic.creator) }
        respond_with(@forum_topic)
      end

      def create
        @forum_topic = authorize(ForumTopic.find(params[:id]), :move?)
        @category = ForumCategory.find_by(id: permitted_attributes(ForumTopic, :move)[:category_id])
        return render_expected_error(404, "Category not found.") unless @category
        return render_expected_error(403, "You cannot move topics into categories you cannot create within.") unless @category.can_create_within?(CurrentUser.user)
        return render_expected_error(403, "You cannot move topics into categories the topic creator cannot create within.") unless @category.can_create_within?(@forum_topic.creator)
        @forum_topic.update(category: @category)
        notice("Forum topic moved")
        respond_with(@forum_topic)
      end
    end
  end
end
