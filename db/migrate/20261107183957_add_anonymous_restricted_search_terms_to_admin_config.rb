# frozen_string_literal: true

class AddAnonymousRestrictedSearchTermsToAdminConfig < ActiveRecord::Migration[8.1]
  before { admin_config_override! }
  after { AdminConfig.delete_cache }

  def change
    add_column(:admin_config, :anonymous_restricted_search_terms, :string, default: "", null: false)
  end
end
