# frozen_string_literal: true

class PostSearchContext
  attr_reader(:post, :user)

  def initialize(params, user)
    @user = user
    tags = params[:q].presence || params[:tags].presence || ""
    tags += " rating:s" if user.safe_mode? && Feature.enabled?(:ratings)
    tags += " -status:deleted" unless TagQuery.has_metatag?(tags, "status", "-status")
    pagination_mode = params[:seq] == "prev" ? "a" : "b"
    @post = Post.tag_match(tags, user).paginate("#{pagination_mode}#{params[:id]}", limit: 1).first || Post.find(params[:id])
  end
end
