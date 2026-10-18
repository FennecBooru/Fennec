# frozen_string_literal: true

module Tags
  class CategoriesController < ApplicationController
    respond_to(:html, :json)
    respond_to(:css, only: %i[styles])
    skip_before_action(:api_check, only: %i[styles])
    before_action(:load_tag_category, only: %i[edit update destroy transfer_tags])

    def index
      # not paginated, reordering needs every category on the page
      @tag_categories = authorize(TagCategory).html_includes(request, :updater).search_current(search_params(TagCategory))
      respond_with(@tag_categories)
    end

    def new
      @tag_category = authorize(TagCategory.new_with_current(:creator, permitted_attributes(TagCategory)))
    end

    def edit
      authorize(@tag_category)
    end

    def create
      @tag_category = authorize(TagCategory.new_with_current(:creator, permitted_attributes(TagCategory)))
      @tag_category.save
      respond_with(@tag_category, location: tag_categories_path)
    end

    def update
      authorize(@tag_category)
      @tag_category.update_with_current(:updater, permitted_attributes(@tag_category))
      removed = @tag_category.errors.empty? ? @tag_category.removed_code_references : {}
      if removed.any?
        notice("Tag category updated. No category is called #{removed.keys.to_sentence} anymore, so these stop working: #{removed.values.join('; ')}")
      end
      respond_with(@tag_category, location: tag_categories_path)
    end

    def destroy
      authorize(@tag_category)
      @tag_category.remove(CurrentUser.user)
      respond_with(@tag_category, location: tag_categories_path)
    end

    # Moves every tag in the category into another, so it can be deleted
    def transfer_tags
      authorize(@tag_category)
      return respond_with(@tag_category) if request.get?

      new_category = TagCategory.active.find_by(id: permitted_attributes(@tag_category)[:new_category_id])
      return render_expected_error(400, "Choose another category to move the tags to") if new_category.nil? || new_category.id == @tag_category.id

      @tag_category.transfer_tags(new_category, CurrentUser.user)
      respond_to do |format|
        format.html { redirect_to(tag_categories_path, notice: "The category is locked while its tags move to #{new_category.name}, it can be deleted once they're done") }
        format.json { head(:no_content) }
      end
    end

    # Sets every category's position, from a list of { id, position } covering all of them, only their order matters
    def reorder
      authorize(TagCategory)
      order = Array(params[:_json]).sort_by { |data| data[:position].to_i }.map { |data| data[:id].to_i }
      current_ids = TagCategory.active.pluck(:id)
      missing = current_ids - order
      extra = order - current_ids
      duplicate = order.select { |id| order.count(id) > 1 }.uniq

      return render_expected_error(400, "No categories provided") if order.empty?
      return render_expected_error(400, "Missing ids: #{missing.join(', ')}") if missing.any?
      return render_expected_error(400, "Extra ids provided: #{extra.join(', ')}") if extra.any?
      return render_expected_error(400, "Duplicate ids provided: #{duplicate.join(', ')}") if duplicate.any?

      # renumbered from 0 in the order given, so positions can't end up duplicated
      positions = order.each_with_index.to_h

      changes = 0
      TagCategory.transaction do
        TagCategory.active.find_each do |category|
          next if category.position == positions[category.id]
          category.update_columns(position: positions[category.id], updated_at: Time.current)
          changes += 1
        end
      end
      # update_columns skips the callback that does this
      TagCategory.clear_cache
      TagCategory.log_reorder(changes, CurrentUser.user) if changes != 0

      respond_to do |format|
        format.html { redirect_to(tag_categories_path) }
        format.json { head(:no_content) }
      end
    end

    # The colors for every category. Linked with the categories' version, so it can be cached for a long time. Not public
    # since the response can set the session cookie
    def styles
      authorize(TagCategory)
      @tag_categories = TagCategory.categories
      expires_in(1.year) if params[:v] == TagCategory.version
      render(formats: :css)
    end

    private

    def load_tag_category
      @tag_category = TagCategory.active.find(params[:id])
    end
  end
end
