# frozen_string_literal: true

FactoryBot.define do
  factory(:uploader_button) do
    creator(factory: %i[admin_user])
    section(factory: %i[uploader_section])
    sequence(:name) { |n| "Test Button #{n}" }
  end
end
