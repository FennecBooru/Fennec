# frozen_string_literal: true

module Uploads
  class ButtonsController < ApplicationController
    respond_to(:html, :json)
    before_action(:block_apikey_authentication, except: %i[index])
    before_action(:load_section)
    before_action(:load_button, only: %i[edit update destroy])

    def index
      # not paginated, reordering needs every button on the page
      @buttons = authorize(UploaderButton).html_includes(request, :updater).where(section: @section).order(:row, :position, :id)
      respond_with(@buttons)
    end

    def new
      @button = authorize(UploaderButton.new_with_current(:creator, { section: @section }, permitted_attributes(UploaderButton)))
    end

    def edit
      authorize(@button)
    end

    def create
      @button = authorize(UploaderButton.new_with_current(:creator, { section: @section }, permitted_attributes(UploaderButton)))
      @button.save
      respond_with(@button, location: upload_section_buttons_path(@section))
    end

    def update
      authorize(@button)
      @button.update_with_current(:updater, permitted_attributes(@button))
      respond_with(@button, location: upload_section_buttons_path(@section))
    end

    def destroy
      authorize(@button)
      @button.destroy_with_current(:destroyer)
      if @button.errors.any?
        respond_to do |format|
          format.html { redirect_to(upload_section_buttons_path(@section), notice: @button.errors.full_messages.join("; ")) }
          format.json { render_expected_error(422, @button.errors.full_messages.join("; ")) }
        end
        return
      end
      respond_with(@button, location: upload_section_buttons_path(@section))
    end

    # Sets the position of every button in the section, from a list of { id, position } covering all of them. Buttons
    # stay in their row, so this only orders them within it
    def reorder
      authorize(UploaderButton)
      order = Array(params[:_json]).sort_by { |data| data[:position].to_i }.map { |data| data[:id].to_i }
      current_ids = @section.buttons.pluck(:id)
      missing = current_ids - order
      extra = order - current_ids
      duplicate = order.select { |id| order.count(id) > 1 }.uniq

      return render_expected_error(400, "No buttons provided") if order.empty?
      return render_expected_error(400, "Missing ids: #{missing.join(', ')}") if missing.any?
      return render_expected_error(400, "Extra ids provided: #{extra.join(', ')}") if extra.any?
      return render_expected_error(400, "Duplicate ids provided: #{duplicate.join(', ')}") if duplicate.any?

      positions = order.each_with_index.to_h

      changes = 0
      UploaderButton.transaction do
        @section.buttons.each do |button|
          next if button.position == positions[button.id]
          button.update_columns(position: positions[button.id], updated_at: Time.current)
          changes += 1
        end
      end
      # update_columns skips the callback that does this
      UploaderSection.clear_cache
      UploaderButton.log_reorder(@section, changes, CurrentUser.user) if changes != 0

      respond_to do |format|
        format.html { redirect_to(upload_section_buttons_path(@section)) }
        format.json { head(:no_content) }
      end
    end

    private

    def load_section
      @section = UploaderSection.find(params[:upload_section_id])
    end

    def load_button
      @button = @section.buttons.find(params[:id])
    end
  end
end
