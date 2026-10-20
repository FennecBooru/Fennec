# frozen_string_literal: true

module Tags
  # Only reached when nginx doesn't send /tags/autocomplete.json to autocompleted
  class AutocompleteController < ApplicationController
    respond_to(:json)

    def show
      authorize(Tag, :autocomplete?)
      results = TagAutocomplete.search(params.dig(:search, :name_matches))
      raise(ActionController::BadRequest, "name_matches must be 3 to 100 characters") if results.nil?
      expires_in(7.days, public: true)
      render(json: results)
    end
  end
end
