# frozen_string_literal: true

module Artists
  class VersionsController < ApplicationController
    before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_artist_pages? || CurrentUser.user.is_staff? })
    respond_to(:html, :json)

    def index
      @artist_versions = authorize(ArtistVersion).html_includes(request, :updater, artist: :wiki_page).search_current(search_params(ArtistVersion)).paginate(params[:page], limit: params[:limit])
      respond_with(@artist_versions)
    end
  end
end
