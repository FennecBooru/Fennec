# frozen_string_literal: true

module Comments
  class VotesController < ApplicationController
    requires_feature(:comments)
    respond_to(:html, only: %i[index])
    respond_to(:json)
    skip_before_action(:api_check)
    before_action(:ensure_lockdown_disabled)

    def index
      @comment_votes = authorize(CommentVote).html_includes(request, :user, comment: %i[creator post])
                                             .search_current(search_params(CommentVote))
                                             .paginate(params[:page], limit: 100)
      respond_with(@comment_votes)
    end

    def create
      authorize(CommentVote)
      @comment = Comment.find(params[:comment_id])
      @comment_vote, @status = VoteManager::Comments.vote!(comment: @comment, user: CurrentUser.user, ip_addr: CurrentUser.ip_addr, score: params[:score])
      if @status == :need_unvote && !params[:no_unvote].to_s.truthy?
        VoteManager::Comments.unvote!(comment: @comment, user: CurrentUser.user)
      end
      @comment.reload
      render(json: { score: @comment.score, our_score: @status == :need_unvote ? 0 : @comment_vote.score, is_locked: @comment_vote.is_locked? })
    rescue UserVote::Error, ActiveRecord::RecordInvalid => e
      render_expected_error(422, e)
    end

    def destroy
      authorize(CommentVote)
      @comment = Comment.find(params[:comment_id])
      VoteManager::Comments.unvote!(comment: @comment, user: CurrentUser.user)
    rescue UserVote::Error => e
      render_expected_error(422, e)
    end

    def lock
      authorize(CommentVote)
      ids = params[:ids].split(",")

      ids.each do |id|
        VoteManager::Comments.lock!(id, CurrentUser.user)
      end
    end

    def delete
      authorize(CommentVote)
      ids = params[:ids].split(",")

      ids.each do |id|
        VoteManager::Comments.admin_unvote!(id, CurrentUser.user)
      end
    end

    private

    def ensure_lockdown_disabled
      access_denied if Security::Lockdown.votes_disabled? && !CurrentUser.user.is_staff?
    end
  end
end
