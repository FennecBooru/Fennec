# frozen_string_literal: true

require("test_helper")

class TagCategoryTest < ActiveSupport::TestCase
  context("A tag category") do
    setup do
      @admin = create(:admin_user)
    end

    context("accessors") do
      should("return the id for a name or alias") do
        assert_equal(1, TagCategory.artist)
        assert_equal(4, TagCategory.character)
        assert_equal(4, TagCategory.char)
      end

      should("return nil for categories that don't exist") do
        assert_nil(TagCategory.doesnotexist)
        assert_not(TagCategory.respond_to?(:doesnotexist))
      end

      should("see categories created during the request") do
        category = create(:tag_category, name: "newcat", aliases: %w[nc])

        assert_equal(category.id, TagCategory.newcat)
        assert_equal(category.id, TagCategory.value_for("nc"))
      end

      should("return nil after a category is deleted") do
        TagCategory.find(TagCategory.artist).tap { |category| category.destroyer = @admin }.destroy

        assert_nil(TagCategory.artist)
      end
    end

    context("creating") do
      should("use the next id") do
        assert_equal(TagCategory.maximum(:id) + 1, create(:tag_category).id)
      end

      should("use a given id") do
        assert_equal(500, create(:tag_category, id: 500).id)
        assert_equal(501, create(:tag_category).id)
      end

      should("not use an id that's taken, out of range, or has had tags") do
        assert_not(build(:tag_category, id: TagCategory.artist).valid?)
        assert_not(build(:tag_category, id: -1).valid?)
        assert_not(build(:tag_category, id: TagCategory::MAX_ID + 1).valid?)

        category = create(:tag_category, id: 600)
        tag = create(:tag, category_id: 600)
        tag.update!(category_id: TagCategory.general, updater: @admin)
        category.update_columns(id: 601)

        assert_includes(build(:tag_category, id: 600).tap(&:valid?).errors[:id], "has had tags before, so it can't be reused")
      end

      should("go at the bottom") do
        last = TagCategory.maximum(:position)

        assert_equal(last + 1, create(:tag_category).position)
        assert_equal(TagCategory.categories.last.id, TagCategory.order(:position).last.id)
      end

      should("not share a position") do
        category = create(:tag_category)

        assert_not(category.update(position: TagCategory.get(:general).position, updater: @admin))
      end

      should("default the header and display to the name") do
        category = create(:tag_category, name: "fancy")

        assert_equal("Fancy", category.header)
        assert_equal("Fancy", category.display)
      end

      should("log a mod action") do
        assert_difference(-> { ModAction.where(action: "tag_category_create").count }, 1) do
          create(:tag_category)
        end
      end
    end

    context("validations") do
      should("only allow lowercase letters in names and aliases") do
        assert_not(build(:tag_category, name: "has_underscore").valid?)
        assert_not(build(:tag_category, aliases: %w[a1]).valid?)
      end

      should("not allow names or aliases used by another category") do
        assert_not(build(:tag_category, name: "art").valid?)
        assert_not(build(:tag_category, aliases: %w[general]).valid?)
      end

      should("not allow metatag or reserved names") do
        assert_not(build(:tag_category, name: "pool").valid?)
        assert_not(build(:tag_category, name: "all").valid?)
      end

      should("not allow names that existing tags start with") do
        create(:tag, name: "foo:bar")

        assert_not(build(:tag_category, name: "foo").valid?)
      end

      should("only allow hex colors") do
        assert_not(build(:tag_category, color: "red").valid?)
        assert_not(build(:tag_category, color_alt: "#12345").valid?)
        assert_predicate(build(:tag_category, color: "#abc", color_alt: "#aabbccdd"), :valid?)
      end

      should("require the format regex to have a capture group") do
        assert_not(build(:tag_category, format_regex: "^.+$").valid?)
        assert_not(build(:tag_category, format_regex: "(").valid?)
        assert_predicate(build(:tag_category, format_regex: "^(.+)$"), :valid?)
      end
    end

    context("renaming") do
      should("keep the old name as an alias") do
        category = TagCategory.find(TagCategory.character)
        category.update!(name: "person", updater: @admin)

        assert_equal(category.id, TagCategory.person)
        assert_equal(category.id, TagCategory.character)
        assert_includes(category.reload.aliases, "character")
      end
    end

    context("the default category") do
      should("be given to new tags") do
        assert_equal(TagCategory.general, Tag.new.category_id)
      end

      should("move when another category is made the default") do
        category = TagCategory.find(TagCategory.meta)
        category.update!(is_default: true, updater: @admin)

        assert_equal(category.id, TagCategory.default_id)
        assert_not(TagCategory.find(TagCategory.general).is_default?)
        assert_equal(category.id, Tag.new.category_id)
      end

      should("not be removable directly") do
        category = TagCategory.find(TagCategory.general)

        assert_not(category.update(is_default: false, updater: @admin))
      end

      should("not be deletable") do
        assert_not(TagCategory.find(TagCategory.general).destroy)
      end
    end

    context("deleting") do
      should("not be allowed while the category has tags") do
        create(:artist_tag)

        assert_not(TagCategory.find(TagCategory.artist).destroy)
      end

      context("a category that had tags") do
        setup do
          @category = create(:tag_category, name: "gone", aliases: %w[gn])
          tag = create(:tag, category_id: @category.id)
          tag.update!(category_id: TagCategory.general, updater: @admin)
        end

        should("be marked deleted and locked instead") do
          assert_difference(-> { TagCategory.unscoped.count } => 0, -> { ModAction.where(action: "tag_category_delete").count } => 1) do
            assert(@category.remove(@admin))
          end

          @category.reload

          assert_predicate(@category, :is_deleted?)
          assert_equal(User::Levels::LOCKED, @category.min_level)
          assert_nil(@category.position)
        end

        should("look like it doesn't exist") do
          @category.remove(@admin)

          assert_nil(TagCategory.gone)
          assert_nil(TagCategory.get(@category.id))
          assert_not_includes(TagCategory.ids, @category.id)
          assert_not_includes(TagCategory.mapping.keys, "gn")
          assert_equal(TagCategory.default_id, TagCategory.value_for("gone"))
          assert_equal("Deleted Category (#{@category.id})", Tag.category_for_value(@category.id))
        end

        should("free its names but not its id") do
          @category.remove(@admin)

          assert_predicate(create(:tag_category, name: "gone", aliases: %w[gn]), :persisted?)
          assert_not(build(:tag_category, id: @category.id).valid?)
          assert_operator(create(:tag_category).id, :>, @category.id)
        end

        should("still need its tags moved first") do
          create(:tag, category_id: @category.id)

          assert_not(@category.remove(@admin))
          assert_not(@category.reload.is_deleted?)
        end
      end

      should("work for unused categories") do
        category = create(:tag_category)

        assert_difference(-> { TagCategory.unscoped.count } => -1, -> { ModAction.where(action: "tag_category_delete").count } => 1) do
          category.remove(@admin)
        end
      end
    end

    context("code references") do
      should("match the category names the code uses") do
        registry_methods = TagCategory.methods.map(&:to_s)
        # predicates and post methods can't be told apart from other methods, so only the default names are checked
        defaults = YAML.load_file(TagCategory::DEFAULTS_FILE).flat_map { |row| [row["name"], *row["aliases"]] }.join("|")
        patterns = [
          /TagCategory\.([a-z]+)\b/,
          /in_category\(:([a-z]+)\)/,
          /\.(#{defaults})\?/,
          /\b(#{defaults})_(?:tags|tag_array)\b/,
          /\btag_count_(#{defaults})\b/,
          /color-tag-(#{defaults})\b/,
          /TAG_CATEGORIES\.([a-z]+)/,
        ]
        files = Rails.root.glob("{app,lib,config}/**/*.{rb,erb,js,vue,scss}").reject { |path| path.to_s.include?("lib/dtext_rb") || path.basename.to_s == "tag_category.rb" }

        used = files.flat_map { |path| patterns.flat_map { |pattern| path.read.scan(pattern).flatten } }.uniq - registry_methods
        used = used.map { |name| TagCategory.get(name)&.name || name }.uniq

        assert_equal(TagCategory::CODE_REFERENCES.keys.sort, used.sort)
      end

      should("list the ones a category has") do
        assert_equal(%w[character], TagCategory.get(:character).code_references.keys)
        assert_empty(TagCategory.get(:lore).code_references)
      end

      should("know when a save removes one") do
        category = TagCategory.get(:character).then { |c| TagCategory.find(c.id) }
        category.update!(name: "person", updater: @admin)

        assert_empty(category.removed_code_references)

        category.update!(aliases: category.aliases - %w[character], updater: @admin)

        assert_equal(%w[character], category.removed_code_references.keys)
        assert_equal(%w[character], TagCategory.missing_code_references.keys)
      end
    end

    context("the minimum level") do
      should("restrict who can use the category") do
        category = TagCategory.get(:invalid)

        assert_equal(User::Levels::ADMIN, category.min_level)
        assert_not(category.can_use?(create(:moderator_user)))
        assert(category.can_use?(create(:admin_user)))
        assert(category.can_use?(User.system))
      end

      should("stop lower users from moving tags into the category") do
        tag = create(:tag)

        assert_not(tag.update(category_id: TagCategory.invalid, updater: create(:moderator_user)))
        assert_includes(tag.errors[:category_id], "can only be used by Admins and above")
      end

      should("only allow real levels") do
        assert_not(build(:tag_category, min_level: 12).valid?)
      end
    end

    context("tag counts") do
      should("follow tags in and out of the category") do
        tag = create(:tag)

        assert_difference(-> { TagCategory.find(TagCategory.general).tag_count } => -1, -> { TagCategory.find(TagCategory.artist).tag_count } => 1) do
          tag.update!(category_id: TagCategory.artist, updater: @admin)
        end
      end

      should("count created and destroyed tags") do
        tag = nil
        assert_difference(-> { TagCategory.find(TagCategory.artist).tag_count }, 1) do
          tag = create(:tag, category_id: TagCategory.artist)
        end
        TagVersion.where(tag_id: tag.id).delete_all
        assert_difference(-> { TagCategory.find(TagCategory.artist).tag_count }, -1) do
          tag.destroy!
        end
      end
    end

    context("dynamic helpers") do
      setup do
        @artist = create(:artist_tag, name: "some_artist")
        @post = create(:post, tag_string: "some_artist tag1")
      end

      should("work on tags") do
        assert_predicate(@artist, :artist?)
        assert_predicate(@artist, :art?)
        assert_not(@artist.general?)
        assert_not(@artist.doesnotexist?)
      end

      should("work on posts") do
        assert_equal(%w[some_artist], @post.artist_tag_array)
        assert_equal(1, @post.tag_count_artist)
        assert_equal(%w[some_artist], @post.artist_tags.map(&:name))
        assert_equal([], @post.doesnotexist_tag_array)
        assert_equal(0, @post.tag_count_doesnotexist)
      end

      should("work for scopes") do
        assert_equal([@artist.id], Tag.artist.pluck(:id))
        assert_equal([@artist.id], Tag.in_category(:artist).pluck(:id))
        assert_empty(Tag.in_category(:doesnotexist))
      end

      should("be empty once the category is gone") do
        category = TagCategory.find(TagCategory.artist)
        category.update!(name: "creator", aliases: [], updater: @admin)
        category.update!(aliases: [], updater: @admin)

        assert_equal([], @post.reload.artist_tag_array)
        assert_equal(%w[some_artist], @post.creator_tag_array)
        assert_not(@artist.reload.artist?)
      end
    end
  end
end
