# frozen_string_literal: true

module TestHelpers
  module AuthMethods
    extend(ActiveSupport::Concern)

    def login_as(user)
      post(session_path, params: { session: { name: user.name, password: user.password } })

      if user.mfa.present?
        post(verify_mfa_session_path, params: { mfa: { user_id: user.signed_id(purpose: :verify_mfa), code: user.mfa.code } })
      end
    end

    def method_authenticated(method_name, url, user, options)
      login_as(user)
      send(method_name, url, **options)
    end

    def method_api_key_authenticated(method_name, url, user, options)
      api_key = create(:api_key, user: user)
      headers = { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(user.name, api_key.key) }
      send(method_name, url, **options, headers: headers.merge(options[:headers] || {}))
    end

    def get_auth(url, user, options = {})
      method_authenticated(:get, url, user, options)
    end

    def post_auth(url, user, options = {})
      method_authenticated(:post, url, user, options)
    end

    def put_auth(url, user, options = {})
      method_authenticated(:put, url, user, options)
    end

    def patch_auth(url, user, options = {})
      method_authenticated(:patch, url, user, options)
    end

    def delete_auth(url, user, options = {})
      method_authenticated(:delete, url, user, options)
    end

    # every path responds with 501, since its feature is turned off
    def assert_feature_unavailable(paths, as:)
      Array(paths).each do |path|
        get_auth(path, as)

        assert_response(:not_implemented, path)
      end
    end
  end
end
