# frozen_string_literal: true

module WikiPages
  class MergesController < ApplicationController
    requires_feature(:wiki)
    respond_to(:html, :json)

    rescue_from(WikiPage::MergeError, with: ->(err) { render_expected_error(422, err.message) })

    wrap_parameters(:wiki_page)

    def show
      @wiki_page = authorize(WikiPage.find(params[:id]), :merge?)
      respond_with(@wiki_page)
    end

    def create
      @wiki_page = authorize(WikiPage.find(params[:id]), :merge?)
      attr = permitted_attributes(WikiPage, :merge)
      if attr[:target_wiki_page_id].present?
        @target = WikiPage.find_by(id: attr[:target_wiki_page_id])
      else
        @target = WikiPage.titled(attr[:target_wiki_page_title])
      end
      authorize(@target, :merge?, policy_class: WikiPagePolicy)
      return render_expected_error(404, "The target wiki page could not be found.") if @target.blank?
      @wiki_page.merge_into!(@target, CurrentUser.user)
      respond_with(@target, notice: "Successfully merged the two wiki pages.")
    end
  end
end
