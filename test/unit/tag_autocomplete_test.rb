# frozen_string_literal: true

require("test_helper")

class TagAutocompleteTest < ActiveSupport::TestCase
  context("Tag autocomplete") do
    setup do
      @user = create(:user)
      @canine = create(:tag, name: "canine", post_count: 100)
      @canid = create(:tag, name: "canid", post_count: 200)
      create(:tag, name: "canvas", post_count: 0)
    end

    should("find tags starting with the query, most used first") do
      assert_equal(%w[canid canine], TagAutocomplete.search("can").pluck(:name))
    end

    should("normalize the query") do
      assert_equal(%w[canid canine], TagAutocomplete.search(" CAN* ").pluck(:name))
    end

    should("treat like wildcards as text") do
      create(:tag, name: "can_opener", post_count: 5)

      assert_equal(%w[can_opener], TagAutocomplete.search("can_").pluck(:name))
    end

    should("include aliases") do
      create(:tag_alias, antecedent_name: "dog", consequent_name: "canine", post_count: 100, creator: @user)
      result = TagAutocomplete.search("dog")

      assert_equal([{ id: @canine.id, name: "canine", post_count: 100, category_id: @canine.category_id, antecedent_name: "dog" }], result)
    end

    should("not include inactive aliases") do
      create(:tag_alias, antecedent_name: "dog", consequent_name: "canine", post_count: 100, status: "pending", creator: @user)

      assert_empty(TagAutocomplete.search("dog"))
    end

    should("fall back to similar names") do
      assert_includes(TagAutocomplete.search("caninee").pluck(:name), "canine")
    end

    should("reject queries that are too short or long") do
      assert_nil(TagAutocomplete.search("ca"))
      assert_nil(TagAutocomplete.search("a" * 101))
      assert_nil(TagAutocomplete.search(nil))
    end
  end
end
