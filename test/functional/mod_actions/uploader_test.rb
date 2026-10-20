# frozen_string_literal: true

require("test_helper")
require_relative("helper")

module ModActions
  class UploaderTest < ActiveSupport::TestCase
    include(Helper)
    include(Rails.application.routes.url_helpers)

    context("mod actions for the uploader") do
      setup do
        @section = create(:uploader_section, creator: @admin, label: "Themes")
        @button = create(:uploader_button, section: @section, creator: @admin, name: "Beach")
        set_count!
      end

      should("format uploader_section_create correctly") do
        section = create(:uploader_section, creator: @admin, label: "Places")

        assert_matches(
          actions: %w[uploader_section_create],
          text:    "Created uploader section \"Places\"",
          subject: section,
          label:   "Places",
        )
      end

      should("format uploader_section_update correctly") do
        @section.update!(label: "Settings", updater: @admin)

        assert_matches(
          actions:   %w[uploader_section_update],
          text:      "Updated uploader section \"Settings\"\nChanged label from \"Themes\" to \"Settings\"",
          subject:   @section,
          label:     "Settings",
          old_label: "Themes",
        )
      end

      should("format uploader_section_delete correctly") do
        @section.destroy_with(@admin)

        assert_matches(
          actions: %w[uploader_section_delete],
          text:    "Deleted uploader section \"Themes\"",
          subject: @section,
          label:   "Themes",
        )
      end

      should("format uploader_sections_reorder correctly") do
        UploaderSection.log_reorder(3, @admin)

        assert_matches(
          actions: %w[uploader_sections_reorder],
          text:    "Changed the order of 3 uploader sections",
          subject: nil,
          total:   3,
        )
      end

      should("format uploader_button_create correctly") do
        button = create(:uploader_button, section: @section, creator: @admin, name: "Forest")

        assert_matches(
          actions:       %w[uploader_button_create],
          text:          "Created uploader button \"Forest\" in \"Themes\"",
          subject:       button,
          name:          "Forest",
          section_label: "Themes",
        )
      end

      should("format uploader_button_update correctly") do
        @button.update!(name: "Seaside", updater: @admin)

        assert_matches(
          actions:       %w[uploader_button_update],
          text:          "Updated uploader button \"Seaside\" in \"Themes\"",
          subject:       @button,
          name:          "Seaside",
          section_label: "Themes",
        )
      end

      should("format uploader_button_delete correctly") do
        @button.destroy_with(@admin)

        assert_matches(
          actions:       %w[uploader_button_delete],
          text:          "Deleted uploader button \"Beach\" from \"Themes\"",
          subject:       @button,
          name:          "Beach",
          section_label: "Themes",
        )
      end

      should("format uploader_buttons_reorder correctly") do
        UploaderButton.log_reorder(@section, 2, @admin)

        assert_matches(
          actions:       %w[uploader_buttons_reorder],
          text:          "Changed the order of 2 uploader buttons in \"Themes\"",
          subject:       nil,
          total:         2,
          section_label: "Themes",
        )
      end
    end
  end
end
