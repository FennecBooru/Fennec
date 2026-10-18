#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

requires_migration!(20261014031322)

# raw sql so User and Post don't have to be loaded during the migration
system_id = TagCategory.connection.select_value("SELECT id FROM users WHERE level = 35 ORDER BY id LIMIT 1")
raise("System user not found") if system_id.nil?

# the existing categories, with the colors from before they were dynamic. The migration fills in the AdminConfig values after
TagCategory.reset_column_information
TagCategory.create_defaults!(creator_id: system_id)
