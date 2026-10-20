# frozen_string_literal: true

# Tag autocomplete for /tags/autocomplete.json, used when autocompleted isn't put in front of it.
# Mirrors autocompleted: tags and aliases starting with the query, falling back to similar names
module TagAutocomplete
  LIMIT = 10
  LENGTH = 3..100
  STATUSES = %w[active processing queued].freeze

  module_function

  # nil if the query is too short or long
  def search(query)
    return nil unless LENGTH.cover?(query.to_s.bytesize)
    query = normalize(query)
    Cache.fetch("tag_autocomplete:#{query}", expires_in: 6.hours) do
      prefix_matches(query).presence || similar_matches(query)
    end
  end

  def normalize(query)
    query.unicode_normalize(:nfc).downcase.delete("*%\0").gsub(/\s/, "")
  end

  def prefix_matches(query)
    pattern = "#{query.gsub(/[\\%_]/) { |c| "\\#{c}" }}%"
    tags = Tag
           .where("tags.name LIKE ?", pattern)
           .where("tags.post_count > 0")
           .order(post_count: :desc)
           .limit(LIMIT)
           .pluck(:id, :name, :post_count, :category_id)
           .map { |row| result(*row) }
    aliases = TagAlias
              .joins("INNER JOIN tags ON tags.name = tag_aliases.consequent_name")
              .where("tag_aliases.antecedent_name LIKE ?", pattern)
              .where(status: STATUSES)
              .where.not("tags.name LIKE ?", pattern)
              .where("tag_aliases.post_count > 0")
              .order("tag_aliases.post_count": :desc)
              .limit(LIMIT * 2)
              .pluck("tags.id", "tags.name", "tags.post_count", "tags.category_id", "tag_aliases.antecedent_name")
              .map { |row| result(*row) }
    (tags + aliases).uniq { |tag| tag[:name] }.sort_by.with_index { |tag, i| [-tag[:post_count], i] }.first(LIMIT)
  end

  def similar_matches(query)
    Tag
      .where("tags.name % ?", query)
      .where("tags.post_count > 0")
      .order(Arel.sql(Tag.sanitize_sql_array(["trunc(3 * similarity(tags.name, ?)) DESC, tags.post_count DESC, tags.name DESC", query])))
      .limit(LIMIT)
      .pluck(:id, :name, :post_count, :category_id)
      .map { |row| result(*row) }
  end

  def result(id, name, post_count, category_id, antecedent_name = nil)
    { id: id, name: name, post_count: post_count, category_id: category_id, antecedent_name: antecedent_name }
  end
end
