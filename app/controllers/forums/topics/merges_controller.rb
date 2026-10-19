# frozen_string_literal: true

module Forums
  module Topics
    class MergesController < ApplicationController
      before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_forums? })
      respond_to(:html, :json)

      rescue_from(ForumTopic::MergeError, with: ->(err) { render_expected_error(422, err.message) })

      wrap_parameters(:forum_topic)

      def show
        @forum_topic = authorize(ForumTopic.find(params[:id]), :merge?)
        check_merge
        respond_with(@forum_topic)
      end

      def create
        @forum_topic = authorize(ForumTopic.find(params[:id]), :merge?)
        check_merge
        @target = authorize(ForumTopic.find_by(id: permitted_attributes(ForumTopic, :merge)[:target_topic_id]), :merge?, policy_class: ForumTopicPolicy)
        return render_expected_error(404, "The target topic could not be found.") if @target.blank?
        @forum_topic.merge_into!(@target, CurrentUser.user)
        respond_with(@target, notice: "Successfully merged the two topics.")
      end

      def undo
        @forum_topic = authorize(ForumTopic.find(params[:id]), :unmerge?)
        check_unmerge
        respond_with(@forum_topic)
      end

      def destroy
        @forum_topic = authorize(ForumTopic.find(params[:id]), :unmerge?)
        check_unmerge
        @forum_topic.undo_merge!(CurrentUser.user)
        respond_with(@forum_topic)
      end

      private

      def check_merge
        raise(ForumTopic::MergeError, "Topic is already merged") if @forum_topic.is_merged?
      end

      def check_unmerge
        raise(ForumTopic::MergeError, "Topic is not merged") unless @forum_topic.is_merged?
      end
    end
  end
end
