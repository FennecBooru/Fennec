# frozen_string_literal: true

class AddDbExportsPathToConfig < ActiveRecord::Migration[7.1]
  before { config_override! }
  after { Config.delete_cache }

  def change
    add_column(:config, :db_exports_path, :string, default: "/db_exports")
  end
end
