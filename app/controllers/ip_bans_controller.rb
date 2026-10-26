# frozen_string_literal: true

class IpBansController < ApplicationController
  respond_to(:html, :json)
  before_action(:block_apikey_authentication)

  def index
    @ip_bans = authorize(IpBan).html_includes(request, :creator)
                               .search_current(search_params(IpBan))
                               .paginate(params[:page], limit: params[:limit])
    respond_with(@ip_bans)
  end

  def new
    @ip_ban = authorize(IpBan.new_with_current(:creator, permitted_attributes(IpBan)))
  end

  def create
    @ip_ban = authorize(IpBan.new_with_current(:creator, permitted_attributes(IpBan)))
    @ip_ban.save
    respond_with(@ip_ban, location: ip_bans_path)
  end

  def destroy
    @ip_ban = authorize(IpBan.find(params[:id]))
    @ip_ban.destroy_with_current(:destroyer)
    respond_with(@ip_ban)
  end
end
