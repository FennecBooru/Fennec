# frozen_string_literal: true

require("test_helper")

class UploaderSectionTest < ActiveSupport::TestCase
  context("An uploader section") do
    setup do
      @admin = create(:admin_user)
    end

    context("defaults") do
      should("include every built in section once") do
        assert_same_elements(UploaderSection::BUILTIN_KINDS, UploaderSection.where.not(kind: "tags").pluck(:kind))
      end

      should("not create anything again") do
        assert_no_difference(-> { UploaderSection.count } => 0, -> { UploaderButton.count } => 0) do
          UploaderSection.create_defaults!(creator_id: @admin.id)
        end
      end

      should("recreate a deleted section at the end") do
        section = UploaderSection.find_by!(key: "artist")
        section.destroy_with(@admin)
        UploaderSection.create_defaults!(creator_id: @admin.id)

        assert_equal(UploaderSection.maximum(:position), UploaderSection.find_by!(key: "artist").position)
      end

      should("only show buttons by tags other buttons have") do
        tags = UploaderButton.pluck(:tag)

        UploaderButton.find_each do |button|
          assert_empty(button.shown_when - tags, "#{button.name} is shown by tags no button has")
        end
      end
    end

    should("put new sections at the end") do
      section = create(:uploader_section, creator: @admin)

      assert_equal(UploaderSection.maximum(:position), section.position)
    end

    should("use the kind as the key for built in sections") do
      section = UploaderSection.find_by!(kind: "rating")
      section.update(key: "something_else", updater: @admin)

      assert_equal("rating", section.reload.key)
    end

    should("not allow changing the kind") do
      section = create(:uploader_section, creator: @admin)
      section.update(kind: "parent", updater: @admin)

      assert_includes(section.errors[:kind], "can't be changed")
    end

    should("not allow reserved keys") do
      section = build(:uploader_section, creator: @admin, key: "other")

      assert_not(section.valid?)
      assert_includes(section.errors[:key], "is reserved")
    end

    should("not allow keys with other characters") do
      section = build(:uploader_section, creator: @admin, key: "Bad Key")

      assert_not(section.valid?)
    end

    should("only allow requirements on tags sections") do
      section = UploaderSection.find_by!(kind: "parent")
      section.update(requirement: "always", updater: @admin)

      assert_includes(section.errors[:requirement], "can only be set on tags sections")
    end

    should("not allow turning off the required sections") do
      UploaderSection::REQUIRED_KINDS.each do |kind|
        section = UploaderSection.find_by!(kind: kind)
        section.update(is_enabled: false, updater: @admin)

        assert_predicate(section.errors, :any?, kind)
      end
    end

    should("allow turning off other built in sections") do
      section = UploaderSection.find_by!(kind: "sources")
      section.update(is_enabled: false, updater: @admin)

      assert_empty(section.errors)
    end

    context("when deleted") do
      should("not delete built in sections") do
        section = UploaderSection.find_by!(kind: "description")

        assert_no_difference(-> { UploaderSection.count }) do
          section.destroy_with(@admin)
        end
        assert_includes(section.errors[:base], "Built in sections can't be deleted")
      end

      should("delete its buttons") do
        section = create(:uploader_section, creator: @admin)
        create(:uploader_button, section: section, creator: @admin)

        assert_difference(-> { UploaderSection.count } => -1, -> { UploaderButton.count } => -1) do
          section.destroy_with(@admin)
        end
      end

      should("not delete a section whose buttons show buttons in other sections") do
        # the cub variants are shown by the gender buttons
        section = UploaderSection.find_by!(key: "character")

        assert_no_difference(-> { UploaderSection.count }) do
          section.destroy_with(@admin)
        end
        assert_match(/Male Cub/, section.errors[:base].join)
      end
    end

    context("layout") do
      should("include the enabled sections in order") do
        UploaderSection.find_by!(kind: "sources").update!(is_enabled: false, updater: @admin)

        layout = UploaderSection.layout

        assert_equal(UploaderSection.where(is_enabled: true).order(:position).pluck(:key), layout.pluck(:key))
        assert_not_includes(layout.pluck(:key), "sources")
      end

      should("group buttons into rows") do
        rows = UploaderSection.layout.find { |section| section[:key] == "content" }[:rows]

        assert_equal(%w[cub baby toddler child teenager], rows.first.pluck(:tag))
        assert_equal({ name: "Male Cub", tag: "male_cub", shown_when: %w[cub male], shown_when_mode: "all" }, rows.second.first)
      end

      should("be updated when a section or button changes") do
        UploaderSection.layout
        UploaderSection.find_by!(key: "artist").update!(label: "Creators", updater: @admin)

        assert_equal("Creators", UploaderSection.layout.find { |section| section[:key] == "artist" }[:label])

        create(:uploader_button, section: UploaderSection.find_by!(key: "artist"), name: "Anonymous Artist", creator: @admin)

        assert_equal("anonymous_artist", UploaderSection.layout.find { |section| section[:key] == "artist" }[:rows].flatten.first[:tag])
      end
    end
  end
end
