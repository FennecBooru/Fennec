# frozen_string_literal: true

module Middleware
  # A cheap guess at whether a request is from a user, for middleware that runs before the app loads them
  module RequestIdentity
    module_function

    # The session and remember cookie are signed so they can't be faked. An api key can be, but a bad one is rejected
    # before the request does any real work.
    def claims_user?(env)
      request = ActionDispatch::Request.new(env)
      return true if request.authorization.present?
      return true if request.GET["login"].present? && request.GET["api_key"].present?
      request.session[:user_id].present? || request.cookie_jar.encrypted[:remember].present?
    rescue StandardError
      false
    end
  end
end
