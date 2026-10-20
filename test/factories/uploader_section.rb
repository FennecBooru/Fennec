# frozen_string_literal: true

FactoryBot.define do
  factory(:uploader_section) do
    creator(factory: %i[admin_user])
    kind { "tags" }
    # keys can only have letters and underscores
    sequence(:key) { |n| "testsection_#{n.to_s(26).tr('0-9a-p', 'a-z')}" }
    label { "Test Section" }
  end
end
