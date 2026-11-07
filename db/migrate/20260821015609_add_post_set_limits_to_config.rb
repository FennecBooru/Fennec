# frozen_string_literal: true

class AddPostSetLimitsToConfig < ActiveRecord::Migration[8.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :post_set_create_limit, :integer, null: false, default: 6)
    add_column(:config, :post_set_create_limit_bypass, :integer, null: false, default: User::Levels::JANITOR)
    add_column(:config, :post_set_limit, :jsonb, null: false, default: {
      User::Levels::REJECTED => 5,
      User::Levels::MEMBER   => 75,
      User::Levels::TRUSTED  => 150,
      User::Levels::ADMIN    => -1,
    })
  end
end
