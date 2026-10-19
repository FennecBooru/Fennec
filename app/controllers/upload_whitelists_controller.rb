# frozen_string_literal: true

class UploadWhitelistsController < ApplicationController
  respond_to(:html, :json, :js)
  # the uploader still checks urls through is_allowed
  requires_feature(:upload_whitelist, except: %i[is_allowed])
  before_action(:load_whitelist, only: %i[edit update destroy])

  def index
    @whitelists = authorize(UploadWhitelist).search_current(search_params(UploadWhitelist))
                                            .paginate(params[:page], limit: params[:limit])
    respond_with(@whitelists)
  end

  def new
    @whitelist = authorize(UploadWhitelist.new_with_current(:creator))
  end

  def edit
    authorize(@whitelist)
    respond_with(@whitelist)
  end

  def create
    @whitelist = authorize(UploadWhitelist.new_with_current(:creator, permitted_attributes(UploadWhitelist)))
    @whitelist.save
    respond_with(@whitelist, location: upload_whitelists_path)
  end

  def update
    authorize(@whitelist)
    @whitelist.update_with_current(:updater, permitted_attributes(@whitelist))
    notice(@whitelist.valid? ? "Entry updated" : @whitelist.errors.full_messages.join("; "))
    redirect_to(upload_whitelists_path)
  end

  def destroy
    authorize(@whitelist)
    @whitelist.destroy_with_current(:destroyer)
    respond_with(@whitelist)
  end

  def is_allowed
    authorize(UploadWhitelist)
    begin
      url_parsed = Addressable::URI.heuristic_parse(params[:url])
      allowed, reason = UploadWhitelist.is_whitelisted?(url_parsed, CurrentUser.user)
      @whitelist = {
        url:        params[:url],
        domain:     url_parsed.domain,
        is_allowed: allowed,
        reason:     reason,
      }
    rescue Addressable::URI::InvalidURIError
      @whitelist = {
        url:        params[:url],
        domain:     "invalid domain",
        is_allowed: false,
        reason:     "invalid domain",
      }
    end
    respond_with(@whitelist) do |format|
      format.json { render(json: @whitelist) }
    end
  end

  private

  def load_whitelist
    @whitelist = UploadWhitelist.find(params[:id])
  end
end
