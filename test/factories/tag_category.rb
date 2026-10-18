# frozen_string_literal: true

FactoryBot.define do
  factory(:tag_category) do
    creator(factory: %i[admin_user])
    # names can only have letters
    sequence(:name) { |n| "testcat#{n.to_s(26).tr('0-9a-p', 'a-z')}" }
    color { "#123456" }
    color_alt { "#654321" }
  end
end
