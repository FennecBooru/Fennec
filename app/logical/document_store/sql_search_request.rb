# frozen_string_literal: true

module DocumentStore
  # Runs a search definition against the database instead of OpenSearch, used when sql_search is
  # enabled. The query builders and paginator are shared, only this executor differs, and it returns
  # a response shaped like OpenSearch's so nothing downstream can tell the difference.
  class SQLSearchRequest
    # OpenSearch's defaults when the request doesn't set them
    DEFAULT_SIZE = 10
    DEFAULT_TRACK_TOTAL_HITS = 10_000

    attr_reader(:definition)

    def initialize(definition, klass)
      @definition = definition
      @klass = klass
    end

    def execute!
      body = definition[:body] || {}
      query = body[:query] || { match_all: {} }
      function_score = query[:function_score]
      query = function_score[:query] if function_score

      translator = SQLQuery.new(@klass)
      relation = translator.relation(query)
      sort = body.key?(:sort) ? body[:sort] : definition[:sort]
      sort = [{ _score: :desc }] if sort.nil? && function_score
      order = translator.order(sort, function_score)

      size = definition.fetch(:size) { body.fetch(:size, DEFAULT_SIZE) }
      from = definition.fetch(:from) { body.fetch(:from, 0) }
      ids = relation.reorder(order.presence && Arel.sql(order)).offset(from).limit(size).pluck(Arel.sql("#{@klass.table_name}.id"))

      track = definition.fetch(:track_total_hits) { body.fetch(:track_total_hits, DEFAULT_TRACK_TOTAL_HITS) }
      total = case track
              when true then relation.count
              when Integer then relation.limit(track).count
              else ids.size
              end

      { "hits" => { "total" => { "value" => total, "relation" => "eq" }, "hits" => ids.map { |id| { "_id" => id.to_s } } } }
    end
  end
end
