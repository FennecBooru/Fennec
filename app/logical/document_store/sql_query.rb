# frozen_string_literal: true

module DocumentStore
  # Translates an OpenSearch query into SQL using the model's document_store.sql definition, which
  # gives the SQL for every indexed field so it matches what as_indexed_json would have indexed.
  class SQLQuery
    ELEMENT_TYPES = { integer: "bigint", long: "bigint", float: "real", date: "timestamp", keyword: "text", text: "text", boolean: "boolean" }.freeze

    def initialize(klass)
      @klass = klass
      @sql = klass.document_store.sql
    end

    def relation(query)
      @klass.unscoped.joins(Array(@sql[:joins])).where(Arel.sql(condition(query)))
    end

    def condition(query, fields = @sql[:fields])
      type, value = query.first
      case type.to_sym
      when :match_all then "TRUE"
      when :match_none then "FALSE"
      when :bool then bool(value, fields)
      when :nested then nested(value, fields)
      when :term, :terms, :range, :exists, :wildcard, :match, :match_phrase_prefix then leaf(type.to_sym, value, fields)
      else raise(ArgumentError, "Unsupported query type: #{type}")
      end
    end

    def order(sort, function_score)
      return "" if sort.nil? || sort.to_s == "_doc"
      Array.wrap(sort).filter_map do |entry|
        field, options = entry.is_a?(Hash) ? entry.first : [entry, :asc]
        options = { order: options } unless options.is_a?(Hash)
        direction = options[:order].to_s.casecmp?("desc") ? "DESC" : "ASC"
        next if field.to_s == "_doc"
        if field.to_s == "_score"
          next unless function_score
          next "#{score(function_score)} #{direction}"
        end

        definition = field(field)
        next if definition.nil?
        expression = sort_expression(definition, direction)
        expression = "COALESCE(#{expression}, #{Float(options[:missing])})" if options[:missing].is_a?(Numeric)
        "#{expression} #{direction} NULLS #{options[:missing].to_s == '_first' ? 'FIRST' : 'LAST'}"
      end.join(", ")
    end

    private

    # with no must clauses, at least one should clause has to match, otherwise they're optional.
    # null clauses are ignored like they are by opensearch
    def bool(value, fields)
      must = (Array.wrap(value[:must]) + Array.wrap(value[:filter])).compact
      should = Array.wrap(value[:should]).compact
      parts = must.map { |q| condition(q, fields) }
      parts += Array.wrap(value[:must_not]).compact.map { |q| "NOT (#{condition(q, fields)})" }
      minimum = value.fetch(:minimum_should_match) { must.empty? ? 1 : 0 }.to_i
      raise(ArgumentError, "Unsupported minimum_should_match: #{minimum}") if minimum > 1
      parts << should.map { |q| "(#{condition(q, fields)})" }.join(" OR ") if should.any? && minimum == 1
      parts.empty? ? "TRUE" : parts.map { |part| "(#{part})" }.join(" AND ")
    end

    def nested(value, fields)
      definition = fields[value[:path].to_s]
      return "FALSE" unless definition&.key?(:nested)
      "EXISTS (SELECT 1 FROM #{definition[:nested]} WHERE #{condition(value[:query], definition[:fields])})"
    end

    def leaf(type, value, fields)
      name, argument = type == :exists ? [value[:field], nil] : value.first
      definition = field(name, fields)
      # querying a field that isn't indexed matches nothing
      return "FALSE" if definition.nil?
      "COALESCE((#{definition.key?(:array) ? array_leaf(type, argument, definition) : scalar_leaf(type, argument, definition)}), FALSE)"
    end

    def scalar_leaf(type, argument, definition)
      expression = scalar_expression(definition)
      case type
      when :term then "#{expression} = #{literal(unwrap(argument, :value), definition)}"
      when :terms then values_in(expression, argument, definition)
      when :range then range(expression, argument, definition)
      when :exists then "#{expression} IS NOT NULL"
      when :wildcard then "#{expression} LIKE #{quote(like_pattern(unwrap(argument, :value)))}"
      when :match then text_match(expression, unwrap(argument, :query))
      when :match_phrase_prefix then phrase_prefix_match(expression, unwrap(argument, :query))
      end
    end

    def array_leaf(type, argument, definition)
      array = "(#{definition[:array]})::#{ELEMENT_TYPES.fetch(definition[:type])}[]"
      case type
      when :term
        value = literal(unwrap(argument, :value), definition)
        definition[:term] ? format(definition[:term], value: value) : "#{array} @> ARRAY[#{value}]"
      when :terms
        values = argument.map { |v| literal(v, definition) }
        values.empty? ? "FALSE" : "#{array} && ARRAY[#{values.join(', ')}]"
      when :exists then "cardinality(#{array}) > 0"
      else
        "EXISTS (SELECT 1 FROM unnest(#{array}) AS element(value) WHERE #{scalar_leaf(type, argument, definition.merge(sql: 'element.value').except(:array))})"
      end
    end

    def range(expression, argument, definition)
      operators = { gt: ">", gte: ">=", lt: "<", lte: "<=" }
      parts = argument.slice(*operators.keys).map { |op, v| "#{expression} #{operators[op]} #{literal(v, definition)}" }
      parts.empty? ? "TRUE" : parts.join(" AND ")
    end

    def values_in(expression, values, definition)
      return "FALSE" if values.empty?
      "#{expression} IN (#{values.map { |v| literal(v, definition) }.join(', ')})"
    end

    # the standard analyzer lowercases and splits on anything that isn't a letter, digit, or underscore
    def tokens(text)
      text.to_s.downcase.scan(/[[:alnum:]_]+/)
    end

    def text_match(expression, text)
      words = tokens(text)
      return "FALSE" if words.empty?
      "lower(#{expression}) ~ #{quote("\\m(#{words.uniq.join('|')})\\M")}"
    end

    # the words in order, with the last one only needing to be the start of a word
    def phrase_prefix_match(expression, text)
      words = tokens(text)
      return "FALSE" if words.empty?
      "lower(#{expression}) ~ #{quote("\\m#{words[..-2].map { |word| "#{word}\\M\\W+" }.join}#{words.last}")}"
    end

    def like_pattern(pattern)
      pattern.to_s.gsub(/[\\%_]/) { |c| "\\#{c}" }.tr("*?", "%_")
    end

    def score(function_score)
      if function_score.key?(:random_score)
        seed = function_score.dig(:random_score, :seed)
        return seed.nil? ? "random()" : "md5(#{@klass.table_name}.id::text || #{quote(seed.to_s)})"
      end
      source = function_score.dig(:script_score, :script, :source)
      @sql.fetch(:scripts, {}).fetch(source) { raise(ArgumentError, "No SQL equivalent for script: #{source}") }
    end

    def sort_expression(definition, direction)
      return "(SELECT #{direction == 'ASC' ? 'MIN' : 'MAX'}(value) FROM unnest(#{definition[:array]}) AS element(value))" if definition.key?(:array)
      expression = scalar_expression(definition)
      definition[:type] == :keyword ? "#{expression} COLLATE \"C\"" : expression
    end

    # floats are stored as single precision and dates to the millisecond
    def scalar_expression(definition)
      case definition[:type]
      when :float then "(#{definition[:sql]})::real"
      when :date then "date_trunc('milliseconds', #{definition[:sql]})"
      else "(#{definition[:sql]})"
      end
    end

    def literal(value, definition)
      case definition[:type]
      when :integer, :long then Integer(value.is_a?(String) ? value : value.to_i).to_s
      when :float then "CAST(#{Float(value)} AS real)"
      when :boolean then value.to_s.truthy? ? "TRUE" : "FALSE"
      when :date then "date_trunc('milliseconds', #{quote(value)}::timestamp)"
      else quote(value.to_s)
      end
    end

    def unwrap(argument, key)
      argument.is_a?(Hash) ? argument[key] : argument
    end

    def field(name, fields = @sql[:fields])
      name = name.to_s
      return fields[name] if fields.key?(name)
      prefix, builder = @sql.fetch(:dynamic_fields, {}).find { |p, _| name.start_with?(p) }
      builder&.call(name.delete_prefix(prefix))
    end

    def quote(value)
      @klass.connection.quote(value)
    end
  end
end
