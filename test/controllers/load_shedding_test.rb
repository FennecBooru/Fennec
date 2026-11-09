# frozen_string_literal: true

require("test_helper")

# Middleware::LoadShedding through the whole stack, so it reads the real session
class LoadSheddingIntegrationTest < ActionDispatch::IntegrationTest
  context("A request that waited for a worker") do
    setup do
      @user = create(:user)
      @headers = { "X-Request-Start" => "t=#{format('%.3f', 3.seconds.ago.to_f)}" }
    end

    should("be turned away when anonymous") do
      get(posts_path, headers: @headers)

      assert_response(:service_unavailable)
    end

    should("be let through when logged in") do
      get_auth(posts_path, @user, headers: @headers)

      assert_response(:success)
    end
  end
end
