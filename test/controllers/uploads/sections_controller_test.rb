# frozen_string_literal: true

require("test_helper")

module Uploads
  class SectionsControllerTest < ActionDispatch::IntegrationTest
    context("The uploader sections controller") do
      setup do
        @admin = create(:admin_user)
        @section = create(:uploader_section, creator: @admin, key: "testing", label: "Testing")
      end

      context("index action") do
        should("render") do
          get_auth(upload_sections_path, @admin)

          assert_response(:success)
        end

        should("list every section by position") do
          get_auth(upload_sections_path(format: :json), @admin)

          assert_equal(UploaderSection.order(:position).pluck(:id), response.parsed_body.pluck("id"))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(upload_sections_path)
          end
        end
      end

      context("new action") do
        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(new_upload_section_path)
            access.none.api_key.get(new_upload_section_path)
          end
        end
      end

      context("edit action") do
        should("render for built in sections") do
          get_auth(edit_upload_section_path(UploaderSection.find_by!(kind: "file")), @admin)

          assert_response(:success)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_upload_section_path(@section) }
            access.none.api_key.get { edit_upload_section_path(@section) }
          end
        end
      end

      context("create action") do
        should("create a tags section") do
          assert_difference(-> { UploaderSection.count } => 1, -> { ModAction.where(action: "uploader_section_create").count } => 1) do
            post_auth(upload_sections_path, @admin, params: { uploader_section: { key: "themes", label: "Themes", placeholder: "beach" } })
          end

          assert_redirected_to(upload_sections_path)
          section = UploaderSection.find_by!(key: "themes")

          assert_equal("tags", section.kind)
          assert_equal("beach", section.placeholder)
        end

        should("not allow picking the kind") do
          assert_no_difference(-> { UploaderSection.count }) do
            post_auth(upload_sections_path, @admin, params: { uploader_section: { key: "anything", label: "Anything", kind: "file" } })
          end

          assert_response(:bad_request)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).post(upload_sections_path).params { { uploader_section: { key: "accesstest", label: "Access" } } }.success(:redirect)
            access.none.api_key.post(upload_sections_path).params { { uploader_section: { key: "accesstest", label: "Access" } } }
          end
        end
      end

      context("update action") do
        should("update a section") do
          assert_difference(-> { ModAction.where(action: "uploader_section_update").count } => 1) do
            put_auth(upload_section_path(@section), @admin, params: { uploader_section: { label: "Renamed", requirement: "always" } })
          end

          assert_redirected_to(upload_sections_path)
          assert_equal("Renamed", @section.reload.label)
          assert_equal("always", @section.requirement)
        end

        should("not change the key") do
          put_auth(upload_section_path(@section), @admin, params: { uploader_section: { key: "changed" } })

          assert_equal("testing", @section.reload.key)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { upload_section_path(@section) }.params({ uploader_section: { label: "Access" } }).success(:redirect)
            access.none.api_key.put { upload_section_path(@section) }.params({ uploader_section: { label: "Access" } })
          end
        end
      end

      context("destroy action") do
        should("delete a tags section") do
          assert_difference(-> { UploaderSection.count } => -1, -> { ModAction.where(action: "uploader_section_delete").count } => 1) do
            delete_auth(upload_section_path(@section), @admin)
          end

          assert_redirected_to(upload_sections_path)
        end

        should("not delete a built in section") do
          assert_no_difference(-> { UploaderSection.count }) do
            delete_auth(upload_section_path(UploaderSection.find_by!(kind: "rating")), @admin)
          end

          assert_redirected_to(upload_sections_path)
          assert_match(/can't be deleted/, flash[:notice])
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { upload_section_path(create(:uploader_section)) }.success(:redirect)
            access.none.api_key.delete { upload_section_path(create(:uploader_section)) }
          end
        end
      end

      context("reorder action") do
        setup do
          # reversed, so every section moves
          @order = UploaderSection.order(:position).pluck(:id).reverse.each_with_index.map { |id, position| { id: id, position: position } }
        end

        should("set every section's position") do
          assert_difference(-> { ModAction.where(action: "uploader_sections_reorder").count } => 1) do
            post_auth(reorder_upload_sections_path(format: :json), @admin, params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })
          end

          assert_response(:no_content)
          assert_equal(@order.pluck(:id), UploaderSection.order(:position).pluck(:id))
          assert_equal(@order.pluck(:id), UploaderSection.layout.map { |section| UploaderSection.find_by!(key: section[:key]).id })
        end

        should("not allow missing sections") do
          post_auth(reorder_upload_sections_path(format: :json), @admin, params: @order[1..].to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:bad_request)
        end

        should("not allow duplicate sections") do
          post_auth(reorder_upload_sections_path(format: :json), @admin, params: [*@order, @order.first].to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:bad_request)
        end

        should("not be allowed for moderators") do
          post_auth(reorder_upload_sections_path(format: :json), create(:moderator_user), params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:forbidden)
        end

        context("access control") do
          asserts do
            access.none.api_key.json.post(reorder_upload_sections_path)
          end
        end
      end
    end
  end
end
