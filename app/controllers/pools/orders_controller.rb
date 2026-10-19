# frozen_string_literal: true

module Pools
  class OrdersController < ApplicationController
    before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_pools? })
    respond_to(:html, :json, :js)

    def edit
      @pool = authorize(Pool.find(params[:pool_id]), policy_class: ::PoolOrderPolicy)
      respond_with(@pool)
    end
  end
end
