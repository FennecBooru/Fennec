# frozen_string_literal: true

require("test_helper")

module Tags
  class CategoriesControllerTest < ActionDispatch::IntegrationTest
    context("The tag categories controller") do
      setup do
        @admin = create(:admin_user)
        @category = create(:tag_category, creator: @admin, name: "testing", aliases: %w[test])
      end

      context("index action") do
        should("render") do
          get_auth(tag_categories_path, @admin)

          assert_response(:success)
        end

        context("with a deleted category") do
          setup do
            @deleted = create(:tag_category, creator: @admin, name: "removed")
            tag = create(:tag, category_id: @deleted.id)
            tag.update!(category_id: TagCategory.general, updater: @admin)
            @deleted.remove(@admin)
          end

          should("leave it out by default") do
            get_auth(tag_categories_path(format: :json), @admin)

            assert_not_includes(response.parsed_body.pluck("id"), @deleted.id)
          end

          should("include it, or only show it, for admins") do
            get_auth(tag_categories_path(format: :json), @admin, params: { search: { deleted: "included" } })

            assert_includes(response.parsed_body.pluck("id"), @deleted.id)
            assert_operator(response.parsed_body.size, :>, 1)

            get_auth(tag_categories_path(format: :json), @admin, params: { search: { deleted: "only" } })

            assert_equal([@deleted.id], response.parsed_body.pluck("id"))
          end

          should("not let others search for it") do
            get_auth(tag_categories_path(format: :json), create(:moderator_user), params: { search: { deleted: "only" } })

            assert_response(:bad_request)
          end

          should("link to it for admins only") do
            get_auth(tag_categories_path, @admin)

            assert_select("a", text: "Show deleted")

            get_auth(tag_categories_path, @admin, params: { search: { deleted: "included" } })

            assert_select("a", text: "Hide deleted")
            assert_select(".edit-order-link", count: 0)

            get_auth(tag_categories_path, create(:moderator_user))

            assert_select("a", text: "Show deleted", count: 0)
          end
        end

        should("list every category by position") do
          get(tag_categories_path(format: :json))

          assert_equal(TagCategory.order(:position, :id).pluck(:id), response.parsed_body.pluck("id"))
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ANONYMOUS).get(tag_categories_path)
          end
        end
      end

      context("styles action") do
        should("include each category's colors") do
          get(styles_tag_categories_path(format: :css, v: TagCategory.version))

          assert_response(:success)
          assert_includes(response.body, "--color-tag-#{@category.id}: #123456;")
          assert_includes(response.body, "--color-tag-test: var(--color-tag-#{@category.id});")
          assert_includes(response.body, ".tag-type-#{@category.id}:hover")
          assert_includes(response.body, ".styled-dtext .dtext-color-testing")
          assert_includes(response.headers["Cache-Control"], "max-age=#{1.year.to_i}")
          assert_includes(response.headers["Cache-Control"], "private")
        end

        should("not be cached for an old version") do
          get(styles_tag_categories_path(format: :css, v: "old"))

          assert_response(:success)
          assert_not_includes(response.headers["Cache-Control"].to_s, "max-age=#{1.year.to_i}")
        end
      end

      context("new action") do
        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get(new_tag_category_path)
          end
        end
      end

      context("edit action") do
        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { edit_tag_category_path(@category) }
          end
        end
      end

      context("create action") do
        should("create a category") do
          assert_difference(-> { TagCategory.count } => 1, -> { ModAction.where(action: "tag_category_create").count } => 1) do
            post_auth(tag_categories_path, @admin, params: { tag_category: { name: "created", aliases_string: "crt", color: "#abcdef", color_alt: "#fedcba" } })
          end

          assert_redirected_to(tag_categories_path)
          assert_equal(%w[crt], TagCategory.find_by(name: "created").aliases)
        end

        should("create a category with a chosen id") do
          post_auth(tag_categories_path, @admin, params: { tag_category: { id: 250, name: "chosen", color: "#abcdef", color_alt: "#fedcba" } })

          assert_equal(250, TagCategory.find_by(name: "chosen").id)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).post(tag_categories_path).params { { tag_category: { name: "accesstest", color: "#abcdef", color_alt: "#fedcba" } } }.success(:redirect)
          end
        end
      end

      context("update action") do
        should("not change the id") do
          put_auth(tag_category_path(@category), @admin, params: { tag_category: { id: 999 } })

          assert(TagCategory.exists?(@category.id))
          assert_not(TagCategory.exists?(999))
        end

        should("update a category") do
          assert_difference(-> { ModAction.where(action: "tag_category_update").count } => 1) do
            put_auth(tag_category_path(@category), @admin, params: { tag_category: { color: "#000000" } })
          end

          assert_redirected_to(tag_categories_path)
          assert_equal("#000000", @category.reload.color)
        end

        should("warn when a name the code uses is removed") do
          category = TagCategory.find(TagCategory.character)
          # renaming keeps the old name as an alias, so it has to be removed separately
          category.update!(name: "person", updater: @admin)
          put_auth(tag_category_path(category), @admin, params: { tag_category: { aliases_string: "char ch oc" } })

          assert_redirected_to(tag_categories_path)
          assert_match(/No category is called character anymore/, flash[:notice])
        end

        should("warn about it on the edit page") do
          get_auth(edit_tag_category_path(TagCategory.find(TagCategory.artist)), @admin)

          assert_select(".notice strong", text: "artist")
        end

        should("show missing ones on the index") do
          category = TagCategory.find(TagCategory.species)
          category.update!(name: "kind", updater: @admin)
          category.update!(aliases: [], updater: @admin)
          get_auth(tag_categories_path, @admin)

          assert_select(".notice strong", text: "species")
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).put { tag_category_path(@category) }.params({ tag_category: { color: "#111111" } }).success(:redirect)
          end
        end
      end

      context("reorder action") do
        setup do
          # reversed, so every category moves
          @order = TagCategory.order(:position, :id).pluck(:id).reverse.each_with_index.map { |id, position| { id: id, position: position } }
        end

        should("set every category's position") do
          assert_difference(-> { ModAction.where(action: "tag_categories_reorder").count } => 1) do
            post_auth(reorder_tag_categories_path(format: :json), @admin, params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })
          end

          assert_response(:no_content)
          assert_equal(@order.pluck(:id), TagCategory.order(:position, :id).pluck(:id))
          assert_equal(@order.pluck(:id), TagCategory.categories.map(&:id))
        end

        should("only use the order of the positions given") do
          order = @order.map { |row| row.merge(position: row[:position] * 10) }
          post_auth(reorder_tag_categories_path(format: :json), @admin, params: order.to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_equal((0...order.size).to_a, TagCategory.order(:position).pluck(:position))
        end

        should("not allow a category twice") do
          order = @order.dup
          order[1] = order[1].merge(id: order[0][:id])
          post_auth(reorder_tag_categories_path(format: :json), @admin, params: order.to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:bad_request)
        end

        should("require every category") do
          post_auth(reorder_tag_categories_path(format: :json), @admin, params: @order.drop(1).to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:bad_request)
        end

        should("not be allowed for moderators") do
          post_auth(reorder_tag_categories_path(format: :json), create(:moderator_user), params: @order.to_json, headers: { "CONTENT_TYPE" => "application/json" })

          assert_response(:forbidden)
        end
      end

      context("transfer tags action") do
        setup do
          @other = create(:tag_category, creator: @admin, name: "other")
          create(:tag, category_id: @category.id)
        end

        should("render") do
          get_auth(transfer_tags_tag_category_path(@category), @admin)

          assert_response(:success)
        end

        should("queue the transfer") do
          assert_enqueued_with(job: TransferTagCategoryTagsJob) do
            post_auth(transfer_tags_tag_category_path(@category), @admin, params: { tag_category: { new_category_id: @other.id } })
          end

          assert_redirected_to(tag_categories_path)
        end

        should("not transfer into the same category") do
          post_auth(transfer_tags_tag_category_path(@category), @admin, params: { tag_category: { new_category_id: @category.id } })

          assert_response(:bad_request)
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).get { transfer_tags_tag_category_path(@category) }
          end
        end
      end

      context("destroy action") do
        should("mark a category that had tags as deleted") do
          tag = create(:tag, category_id: @category.id)
          tag.update!(category_id: TagCategory.general, updater: @admin)
          delete_auth(tag_category_path(@category), @admin)

          assert_redirected_to(tag_categories_path)
          assert_predicate(@category.reload, :is_deleted?)

          get_auth(edit_tag_category_path(@category), @admin)

          assert_response(:not_found)
        end

        should("delete the category") do
          assert_difference(-> { TagCategory.count } => -1, -> { ModAction.where(action: "tag_category_delete").count } => 1) do
            delete_auth(tag_category_path(@category), @admin)
          end
        end

        context("access control") do
          asserts do
            access.gte(User::Levels::ADMIN).delete { tag_category_path(@category) }.success(:redirect)
          end
        end
      end
    end
  end
end
