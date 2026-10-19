# frozen_string_literal: true

module Posts
  class RecommendationsController < ApplicationController
    respond_to(:json, :html)
    before_action(:validate_enabled)

    def show
      authorize(:recommender)
      limit = params.fetch(:limit, 50).to_i.clamp(1, 50)
      sp = search_params
      sp[:post_id] = params[:post_id] if params[:post_id].present?
      sp[:user_id] = params[:user_id] if params[:user_id].present?
      @recs = Recommender.search(sp, CurrentUser.user).take(limit)
      @posts = @recs.pluck(:post)

      respond_with(@recs)
    end

    private

    def validate_enabled
      raise(FeatureUnavailable) unless Recommender.enabled?
    end
  end
end
