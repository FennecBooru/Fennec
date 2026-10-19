# frozen_string_literal: true

module Artists
  class UrlsController < ApplicationController
    before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_artist_pages? || CurrentUser.user.is_staff? })
    respond_to(:json, :html)

    def index
      @artist_urls = authorize(ArtistUrl).includes(:artist)
                                         .search_current(search_params(ArtistUrl))
                                         .paginate(params[:page], limit: params[:limit])
      respond_with(@artist_urls, include: %i[artist])
    end
  end
end
