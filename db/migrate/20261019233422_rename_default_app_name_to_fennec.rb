# frozen_string_literal: true

class RenameDefaultAppNameToFennec < ActiveRecord::Migration[8.1]
  def change
    change_column_default(:admin_config, :app_name, from: "GayFur City", to: "Fennec")
    change_column_default(:admin_config, :canonical_app_name, from: "GayFur City", to: "Fennec")
    change_column_default(:admin_config, :app_description, from: "Your one-stop shop for femboy furries.", to: "Furry image booru.")
    change_column_default(:admin_config, :takedown_email, from: "admin@femboy.fan", to: "admin@localhost")
    change_column_default(:admin_config, :contact_email, from: "admin@femboy.fan", to: "admin@localhost")
  end
end
