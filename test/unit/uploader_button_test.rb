# frozen_string_literal: true

require("test_helper")

class UploaderButtonTest < ActiveSupport::TestCase
  context("An uploader button") do
    setup do
      @admin = create(:admin_user)
      @section = create(:uploader_section, creator: @admin)
    end

    should("default the tag to the name") do
      button = create(:uploader_button, section: @section, name: "Beach Day", creator: @admin)

      assert_equal("beach_day", button.tag)
    end

    should("normalize the tag") do
      button = create(:uploader_button, section: @section, name: "Test", tag: " Some Tag ", creator: @admin)

      assert_equal("some_tag", button.tag)
    end

    should("not allow a tag another button has") do
      button = build(:uploader_button, section: @section, name: "Male", creator: @admin)

      assert_not(button.valid?)
      assert_includes(button.errors[:tag], "has already been taken")
    end

    should("only be added to tags sections") do
      button = build(:uploader_button, section: UploaderSection.find_by!(kind: "rating"), creator: @admin)

      assert_not(button.valid?)
      assert_includes(button.errors[:section], "must be a tags section")
    end

    should("go at the end of the section") do
      first = create(:uploader_button, section: @section, creator: @admin)
      second = create(:uploader_button, section: @section, creator: @admin)

      assert_operator(second.position, :>, first.position)
    end

    context("shown when") do
      should("parse the tags from a string") do
        button = create(:uploader_button, section: @section, shown_when_string: "male, female", creator: @admin)

        assert_equal(%w[male female], button.shown_when)
      end

      should("only allow tags other buttons have") do
        button = build(:uploader_button, section: @section, shown_when_string: "male nonexistent", creator: @admin)

        assert_not(button.valid?)
        assert_match(/nonexistent/, button.errors[:shown_when].join)
      end

      should("not allow its own tag") do
        button = build(:uploader_button, section: @section, name: "Loop", shown_when_string: "loop", creator: @admin)

        assert_not(button.valid?)
        assert_includes(button.errors[:shown_when], "can't include its own tag")
      end

      should("only allow any or all") do
        button = build(:uploader_button, section: @section, shown_when_mode: "some", creator: @admin)

        assert_not(button.valid?)
      end
    end

    context("that shows other buttons") do
      setup do
        @button = UploaderButton.find_by!(tag: "cub")
      end

      should("not be deleted") do
        assert_no_difference(-> { UploaderButton.count }) do
          @button.destroy_with(@admin)
        end
        assert_match(/Baby/, @button.errors[:base].join)
      end

      should("not change its tag") do
        @button.update(tag: "young", updater: @admin)

        assert_match(/Baby/, @button.errors[:tag].join)
      end

      should("be deleted once nothing depends on it") do
        button = create(:uploader_button, section: @section, creator: @admin)
        dependent = create(:uploader_button, section: @section, shown_when: [button.tag], creator: @admin)
        dependent.destroy_with(@admin)

        assert_difference(-> { UploaderButton.count } => -1) do
          button.destroy_with(@admin)
        end
      end
    end
  end
end
