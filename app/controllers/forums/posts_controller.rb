# frozen_string_literal: true

module Forums
  class PostsController < ApplicationController
    before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_forums? })
    respond_to(:html, :json)
    before_action(:load_post, only: %i[edit show update destroy hide unhide warning mark_spam mark_not_spam])
    before_action(:ensure_lockdown_disabled, except: %i[index show])
    skip_before_action(:api_check)

    def index
      @query = authorize(ForumPost).search_current(search_params(ForumPost))
      @forum_posts = @query.paginate(params[:page], limit: params[:limit])
      respond_with(@forum_posts) do |format|
        format.html do
          @forum_posts = @forum_posts.includes(:creator, topic: :category).load
        end
      end
    end

    def show
      authorize(@forum_post)
      @forum_topic = @forum_post.topic
      if request.format.html? && @forum_post.id == @forum_post.topic.original_post.id
        redirect_to(forum_topic_path(@forum_topic, page: params[:page]))
      else
        respond_with(@forum_post)
      end
    end

    def new
      @forum_post = authorize(ForumPost.new_with_current(:creator, permitted_attributes(ForumPost)))
      respond_with(@forum_post)
    end

    def edit
      authorize(@forum_post)
      respond_with(@forum_post)
    end

    def create
      @forum_post = authorize(ForumPost.new_with_current(:creator, permitted_attributes(ForumPost)))
      if @forum_post.valid?
        @forum_post.save
        respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
      else
        respond_with(@forum_post)
      end
    end

    def update
      authorize(@forum_post)
      @forum_post.update_with_current(:updater, permitted_attributes(@forum_post))
      respond_with(@forum_post, location: forum_topic_path(@forum_post.topic, page: @forum_post.forum_topic_page, anchor: "forum_post_#{@forum_post.id}"))
    end

    def destroy
      authorize(@forum_post)
      @forum_post.destroy_with_current(:destroyer)
      respond_with(@forum_post)
    end

    def hide
      authorize(@forum_post)
      @forum_post.hide!(CurrentUser.user)
      respond_with(@forum_post)
    end

    def unhide
      authorize(@forum_post)
      @forum_post.unhide!(CurrentUser.user)
      respond_with(@forum_post)
    end

    def warning
      authorize(@forum_post)
      if params[:record_type] == "unmark"
        @forum_post.remove_user_warning!(CurrentUser.user)
      else
        @forum_post.user_warned!(params[:record_type], CurrentUser.user)
      end
      respond_with_html_after_update
    end

    def mark_spam
      authorize(@forum_post)
      @forum_post.mark_spam!(CurrentUser.user)
      respond_with_html_after_update
    end

    def mark_not_spam
      authorize(@forum_post)
      @forum_post.mark_not_spam!(CurrentUser.user)
      respond_with_html_after_update
    end

    private

    def respond_with_html_after_update
      @forum_topic = @forum_post.topic
      html = render_to_string(partial: "forums/posts/forum_post", locals: { forum_post: @forum_post, original_forum_post_id: @forum_post.topic.original_post.id }, formats: [:html])
      render(json: { html: html, posts: deferred_posts })
    end

    def load_post
      @forum_post = ForumPost.includes(topic: %i[category]).find(params[:id])
    end

    def ensure_lockdown_disabled
      access_denied if Security::Lockdown.forums_disabled? && !CurrentUser.user.is_staff?
    end
  end
end
