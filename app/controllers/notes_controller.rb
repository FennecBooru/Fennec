# frozen_string_literal: true

class NotesController < ApplicationController
  before_action(-> { raise(FeatureUnavailable) unless AdminConfig.enable_notes? })
  respond_to(:html, :json, :js)

  def search
  end

  def index
    @notes = authorize(Note).html_includes(request, :creator)
                            .search_current(search_params(Note))
                            .paginate(params[:page], limit: params[:limit])
    respond_with(@notes) do |format|
      format.html { @notes = @notes.includes(:creator) }
    end
  end

  def show
    @note = authorize(Note.find(params[:id]))
    respond_with(@note) do |format|
      format.html { redirect_to(post_path(@note.post, anchor: "note-#{@note.id}")) }
    end
  end

  def create
    @note = authorize(Note.new_with_current(:creator, permitted_attributes(Note)))
    @note.save
    respond_with(@note) do |fmt|
      fmt.json do
        if @note.errors.any?
          render_expected_error(422, note.errors.full_messages.join("; "))
        else
          render(json: @note.to_json(methods: %i[html_id]))
        end
      end
    end
  end

  def update
    @note = authorize(Note.find(params[:id]))
    @note.update_with_current(:updater, permitted_attributes(@note))
    respond_with(@note) do |format|
      format.json do
        if @note.errors.any?
          render_expected_error(422, @note.errors.full_messages.join("; "))
        else
          render(json: @note.to_json)
        end
      end
    end
  end

  def destroy
    @note = authorize(Note.find(params[:id]))
    @note.soft_delete_with_current(:updater)
    respond_with(@note)
  end

  def revert
    @note = authorize(Note.find(params[:id]))
    @version = @note.versions.find(params[:version_id])
    @note.revert_to!(@version, CurrentUser.user)
    respond_with(@note)
  end
end
