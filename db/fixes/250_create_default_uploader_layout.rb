#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

requires_migration!(20261020120000)

# raw sql so User doesn't have to be loaded during the migration
system_id = UploaderSection.connection.select_value("SELECT id FROM users WHERE level = 35 ORDER BY id LIMIT 1")
raise("System user not found") if system_id.nil?

# the layout the uploader had before it was customizable. The migration fills in the AdminConfig values after
UploaderSection.reset_column_information
UploaderButton.reset_column_information
UploaderSection.create_defaults!(creator_id: system_id)
