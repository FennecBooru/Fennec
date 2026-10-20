# frozen_string_literal: true

require("test_helper")

module Tags
  class AutocompleteControllerTest < ActionDispatch::IntegrationTest
    context("The tag autocomplete controller") do
      setup do
        @tag = create(:tag, name: "canine", post_count: 100)
      end

      should("return matching tags in the same format as autocompleted") do
        get("/tags/autocomplete.json", params: { search: { name_matches: "can" }, expiry: 7 })

        assert_response(:success)
        assert_equal([{ "id" => @tag.id, "name" => "canine", "post_count" => 100, "category_id" => @tag.category_id, "antecedent_name" => nil }], response.parsed_body)
      end

      should("reject short queries") do
        get("/tags/autocomplete.json", params: { search: { name_matches: "ca" } })

        assert_response(:bad_request)
      end

      context("access control") do
        asserts do
          access.gte(User::Levels::ANONYMOUS).json.get(tag_autocomplete_path).params({ search: { name_matches: "can" } })
        end
      end
    end
  end
end
