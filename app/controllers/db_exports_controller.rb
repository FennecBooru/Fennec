# frozen_string_literal: true

class DbExportsController < ApplicationController
  respond_to(:html, :json)
  requires_feature(:db_exports)

  def index
    @exports = DbExport.order(:name, :date)
    respond_with(@exports)
  end
end
