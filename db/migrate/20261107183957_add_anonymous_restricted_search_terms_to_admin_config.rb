class AddAnonymousRestrictedSearchTermsToAdminConfig < ActiveRecord::Migration[8.1]
  with_admin_config_override!

  def change
    add_column(:admin_config, :anonymous_restricted_search_terms, :string, default: "", null: false)
    AdminConfig.delete_cache
  end
end
