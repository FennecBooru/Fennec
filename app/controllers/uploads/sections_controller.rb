# frozen_string_literal: true

module Uploads
  class SectionsController < ApplicationController
    respond_to(:html, :json)
    before_action(:block_apikey_authentication, except: %i[index])
    before_action(:load_section, only: %i[edit update destroy])

    def index
      # not paginated, reordering needs every section on the page
      @sections = authorize(UploaderSection).html_includes(request, :updater, :buttons).order(:position)
      respond_with(@sections)
    end

    def new
      @section = authorize(UploaderSection.new_with_current(:creator, permitted_attributes(UploaderSection)))
    end

    def edit
      authorize(@section)
    end

    # only tags sections can be created, built in ones always exist
    def create
      @section = authorize(UploaderSection.new_with_current(:creator, { kind: "tags" }, permitted_attributes(UploaderSection)))
      @section.save
      respond_with(@section, location: upload_sections_path)
    end

    def update
      authorize(@section)
      @section.update_with_current(:updater, permitted_attributes(@section))
      respond_with(@section, location: upload_sections_path)
    end

    def destroy
      authorize(@section)
      @section.destroy_with_current(:destroyer)
      if @section.errors.any?
        respond_to do |format|
          format.html { redirect_to(upload_sections_path, notice: @section.errors.full_messages.join("; ")) }
          format.json { render_expected_error(422, @section.errors.full_messages.join("; ")) }
        end
        return
      end
      respond_with(@section, location: upload_sections_path)
    end

    # Sets every section's position, from a list of { id, position } covering all of them, only their order matters
    def reorder
      authorize(UploaderSection)
      order = Array(params[:_json]).sort_by { |data| data[:position].to_i }.map { |data| data[:id].to_i }
      current_ids = UploaderSection.pluck(:id)
      missing = current_ids - order
      extra = order - current_ids
      duplicate = order.select { |id| order.count(id) > 1 }.uniq

      return render_expected_error(400, "No sections provided") if order.empty?
      return render_expected_error(400, "Missing ids: #{missing.join(', ')}") if missing.any?
      return render_expected_error(400, "Extra ids provided: #{extra.join(', ')}") if extra.any?
      return render_expected_error(400, "Duplicate ids provided: #{duplicate.join(', ')}") if duplicate.any?

      # renumbered from 0 in the order given, so positions can't end up duplicated
      positions = order.each_with_index.to_h

      changes = 0
      UploaderSection.transaction do
        UploaderSection.find_each do |section|
          next if section.position == positions[section.id]
          section.update_columns(position: positions[section.id], updated_at: Time.current)
          changes += 1
        end
      end
      # update_columns skips the callback that does this
      UploaderSection.clear_cache
      UploaderSection.log_reorder(changes, CurrentUser.user) if changes != 0

      respond_to do |format|
        format.html { redirect_to(upload_sections_path) }
        format.json { head(:no_content) }
      end
    end

    private

    def load_section
      @section = UploaderSection.find(params[:id])
    end
  end
end
