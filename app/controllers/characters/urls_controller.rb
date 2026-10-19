# frozen_string_literal: true

module Characters
  class UrlsController < ApplicationController
    before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_character_pages? })
    respond_to(:json, :html)

    def index
      @character_urls = authorize(CharacterUrl).includes(:character)
                                               .search_current(search_params(CharacterUrl))
                                               .paginate(params[:page], limit: params[:limit])
      respond_with(@character_urls, include: %i[character])
    end
  end
end
