# frozen_string_literal: true

module Security
  class DashboardController < ApplicationController
    respond_to(:html)
    before_action(:block_apikey_authentication)

    def index
      authorize(%i[security dashboard])
    end
  end
end
