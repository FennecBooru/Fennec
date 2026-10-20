# frozen_string_literal: true

class EmailBlacklistsController < ApplicationController
  respond_to(:html, :json, :js)
  requires_email

  def index
    @blacklists = authorize(EmailBlacklist).html_includes(request, :creator)
                                           .search_current(search_params(EmailBlacklist))
                                           .paginate(params[:page], limit: params[:limit])
    respond_with(@blacklists)
  end

  def new
    @blacklist = authorize(EmailBlacklist.new_with_current(:creator))
  end

  def create
    @blacklist = authorize(EmailBlacklist.new_with_current(:creator, permitted_attributes(EmailBlacklist)))
    @blacklist.save
    respond_with(@blacklist, location: email_blacklists_path)
  end

  def destroy
    @blacklist = authorize(EmailBlacklist.find(params[:id]))
    @blacklist.destroy_with_current(:destroyer)
    respond_with(@blacklist)
  end
end
