# frozen_string_literal: true

class AddLockedTagsTrgmIndexToPosts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # TagMover#update_locked_tags! searches this with a leading wildcard for every alias/rename
    add_index(:posts, "(lower(locked_tags)) gin_trgm_ops", using: :gin, algorithm: :concurrently)
  end
end
