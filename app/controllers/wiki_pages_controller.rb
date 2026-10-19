# frozen_string_literal: true

class WikiPagesController < ApplicationController
  # staff keep access, the static and help pages are still wiki pages
  before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_wiki? || CurrentUser.user.is_staff? })
  respond_to(:html, :json, :js)

  def index
    authorize(WikiPage)
    if params[:title].present?
      @wiki_page = WikiPage.titled(params[:title])
      if @wiki_page.nil?
        return redirect_to(show_or_new_wiki_pages_path(title: params[:id])) if request.format.html?
        raise(ActiveRecord::RecordNotFound)
      end
      redirect_to(wiki_page_path(@wiki_page))
    end
    @wiki_pages = WikiPage.html_includes(request, :updater)
                          .search_current(search_params(WikiPage))
                          .paginate(params[:page], limit: params[:limit])
    respond_with(@wiki_pages)
  end

  def show
    if params[:id] =~ /\A\d+\z/
      @wiki_page = authorize(WikiPage.find(params[:id]))
    else
      @wiki_page = WikiPage.titled(params[:id])
    end
    authorize(@wiki_page, policy_class: WikiPagePolicy)
    if @wiki_page.present?
      if @wiki_page.parent.present?
        @wiki_redirect = WikiPage.titled(@wiki_page.parent)
      end
      respond_with(@wiki_page)
    elsif request.format.html?
      redirect_to(show_or_new_wiki_pages_path(title: params[:id]))
    else
      raise(ActiveRecord::RecordNotFound)
    end
  end

  def new
    @wiki_page = authorize(WikiPage.new_with_current(:creator, permitted_attributes(WikiPage)))
    respond_with(@wiki_page)
  end

  def edit
    if params[:id] =~ /\A\d+\z/
      @wiki_page = WikiPage.find(params[:id])
    else
      @wiki_page = WikiPage.titled(params[:id])
      if @wiki_page.nil? && request.format.html?
        redirect_to(show_or_new_wiki_pages_path(title: params[:id]))
        return
      end
    end
    authorize(@wiki_page)
    respond_with(@wiki_page)
  end

  def search
    authorize(WikiPage)
  end

  def create
    @wiki_page = authorize(WikiPage.new_with_current(:creator, permitted_attributes(WikiPage)))
    @wiki_page.save
    respond_with(@wiki_page)
  end

  def update
    @wiki_page = authorize(WikiPage.find(params[:id]))
    @wiki_page.update_with_current(:updater, permitted_attributes(@wiki_page))
    flash[:notice] = @wiki_page.warnings.full_messages.join(".\n \n") if @wiki_page.warnings.any?
    respond_with(@wiki_page)
  end

  def destroy
    @wiki_page = authorize(WikiPage.find(params[:id]))
    @wiki_page.destroy_with_current(:destroyer)
    notice(@wiki_page.valid? ? "Page destroyed" : @wiki_page.errors.full_messages.join("; "))
    respond_with(@wiki_page)
  end

  def revert
    @wiki_page = authorize(WikiPage.find(params[:id]))
    @version = @wiki_page.versions.find(params[:version_id])
    @wiki_page.revert_to!(@version, CurrentUser.user)
    notice("Page was reverted")
    respond_with(@wiki_page)
  end

  def show_or_new
    @wiki_page = authorize(WikiPage.titled(params[:title]), policy_class: WikiPagePolicy)
    if @wiki_page
      redirect_to(wiki_page_path(@wiki_page))
    else
      @wiki_page = WikiPage.new(title: WikiPage.normalize_name(params[:title] || ""))
      respond_with(@wiki_page)
    end
  end
end
