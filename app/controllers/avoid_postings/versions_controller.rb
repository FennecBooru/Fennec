# frozen_string_literal: true

module AvoidPostings
  class VersionsController < ApplicationController
    respond_to(:html, :json)
    before_action(:validate_enabled)

    def index
      @avoid_posting_versions = authorize(AvoidPostingVersion).html_includes(request, :updater, :avoid_posting)
                                                              .search_current(search_params(AvoidPostingVersion))
                                                              .paginate(params[:page], limit: params[:limit])
      respond_with(@avoid_posting_versions)
    end

    private

    def validate_enabled
      raise(FeatureUnavailable) unless AdminConfig.enable_avoid_posting?
    end
  end
end
