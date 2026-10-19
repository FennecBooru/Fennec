# frozen_string_literal: true

class MascotsController < ApplicationController
  requires_feature(:mascots)
  respond_to(:html, :json)

  def index
    @mascots = authorize(Mascot).with_assets
                                .search_current(search_params(Mascot))
                                .paginate(params[:page], limit: params[:limit])
    respond_with(@mascots)
  end

  def new
    @mascot = authorize(Mascot.new_with_current(:creator, permitted_attributes(Mascot)))
  end

  def edit
    @mascot = authorize(Mascot.find(params[:id]))
  end

  def create
    @mascot = authorize(Mascot.new_with_current(:creator, permitted_attributes(Mascot)))
    @mascot.save
    respond_with(@mascot, location: mascots_path)
  end

  def update
    @mascot = authorize(Mascot.find(params[:id]))
    @mascot.update_with_current(:updater, permitted_attributes(@mascot))
    respond_with(@mascot, location: mascots_path)
  end

  def destroy
    @mascot = authorize(Mascot.find(params[:id]))
    @mascot.destroy_with_current(:destroyer)
    respond_with(@mascot)
  end
end
