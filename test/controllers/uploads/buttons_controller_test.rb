# frozen_string_literal: true

require("test_helper")

module Uploads
  class ButtonsControllerTest < ActionDispatch::IntegrationTest
    context("The uploader buttons controller") do
      setup do
        @admin = create(:admin_user)
        @section = create(:uploader_section, creator: @admin)
        @button = create(:uploader_button, section: @section, name: "Testing", creator: @admin)
      end

      context("index action") do
        should("render") do
          get_auth(upload_section_buttons_path(UploaderSection.find_by!(key: "character")), @admin)

          assert_response(:success)
        end

        should("list the section's buttons") do
          get_auth(upload_section_buttons_path(@section, format: :json), @admin)

          assert_equal([@button.id], response.parsed_body.pluck("id"))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { upload_section_buttons_path(@section) }
          end
        end
      end

      context("new action") do
        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { new_upload_section_button_path(@section) }
            access.none.api_key.get { new_upload_section_button_path(@section) }
          end
        end
      end

      context("edit action") do
        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_upload_section_button_path(@section, @button) }
            access.none.api_key.get { edit_upload_section_button_path(@section, @button) }
          end
        end
      end

      context("create action") do
        should("create a button") do
          assert_difference(-> { @section.buttons.count } => 1, -> { ModAction.where(action: "uploader_button_create").count } => 1) do
            post_auth(upload_section_buttons_path(@section), @admin, params: { uploader_button: { name: "Beach Day", row: 2, shown_when_string: "male female", shown_when_mode: "all" } })
          end

          assert_redirected_to(upload_section_buttons_path(@section))
          button = UploaderButton.find_by!(tag: "beach_day")

          assert_equal(2, button.row)
          assert_equal(%w[male female], button.shown_when)
          assert_equal("all", button.shown_when_mode)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).post { upload_section_buttons_path(@section) }.params { { uploader_button: { name: "Access #{SecureRandom.hex(4)}" } } }.success(:redirect)
            access.none.api_key.post { upload_section_buttons_path(@section) }.params { { uploader_button: { name: "Access #{SecureRandom.hex(4)}" } } }
          end
        end
      end

      context("update action") do
        should("update a button") do
          assert_difference(-> { ModAction.where(action: "uploader_button_update").count } => 1) do
            put_auth(upload_section_button_path(@section, @button), @admin, params: { uploader_button: { name: "Renamed", tag: "renamed_tag" } })
          end

          assert_redirected_to(upload_section_buttons_path(@section))
          assert_equal("renamed_tag", @button.reload.tag)
        end

        should("not find buttons from another section") do
          put_auth(upload_section_button_path(UploaderSection.find_by!(key: "artist"), @button), @admin, params: { uploader_button: { name: "Moved" } })

          assert_response(:not_found)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { upload_section_button_path(@section, @button) }.params({ uploader_button: { name: "Access" } }).success(:redirect)
            access.none.api_key.put { upload_section_button_path(@section, @button) }.params({ uploader_button: { name: "Access" } })
          end
        end
      end

      context("destroy action") do
        should("delete a button") do
          assert_difference(-> { UploaderButton.count } => -1, -> { ModAction.where(action: "uploader_button_delete").count } => 1) do
            delete_auth(upload_section_button_path(@section, @button), @admin)
          end

          assert_redirected_to(upload_section_buttons_path(@section))
        end

        should("not delete a button others are shown by") do
          section = UploaderSection.find_by!(key: "content")

          assert_no_difference(-> { UploaderButton.count }) do
            delete_auth(upload_section_button_path(section, section.buttons.find_by!(tag: "cub")), @admin)
          end

          assert_match(/only shown when this button is selected/, flash[:notice])
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { upload_section_button_path(@section, create(:uploader_button, section: @section)) }.success(:redirect)
            access.none.api_key.delete { upload_section_button_path(@section, create(:uploader_button, section: @section)) }
          end
        end
      end

      context("reorder action") do
        setup do
          @section = UploaderSection.find_by!(key: "species")
          @order = @section.buttons.pluck(:id).reverse.each_with_index.map { |id, position| { id: id, position: position } }
        end

        should("set the position of every button in the section") do
          assert_difference(-> { ModAction.where(action: "uploader_buttons_reorder").count } => 1) do
            post_auth(reorder_upload_section_buttons_path(@section, format: :json), @admin, params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })
          end

          assert_response(:no_content)
          # they stay in their rows
          rows = UploaderSection.layout.find { |section| section[:key] == "species" }[:rows]

          assert_equal(%w[taur human humanoid feral anthro], rows.first.pluck(:tag))
          assert_equal("taur/taur", rows.second.first[:tag])
        end

        should("not allow buttons from another section") do
          other = UploaderSection.find_by!(key: "content").buttons.first
          post_auth(reorder_upload_section_buttons_path(@section, format: :json), @admin, params: [*@order, { id: other.id, position: 99 }].to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:bad_request)
        end

        should("not be allowed for moderators") do
          post_auth(reorder_upload_section_buttons_path(@section, format: :json), create(:moderator_user), params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.none.api_key.json.post { reorder_upload_section_buttons_path(@section) }
          end
        end
      end
    end
  end
end
