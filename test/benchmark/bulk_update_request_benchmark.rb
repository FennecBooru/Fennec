# frozen_string_literal: true

require("test_helper")

# Throughput benchmark for bulk update request processing. Not part of the normal suite (no _test
# suffix), run it directly:
#
#   docker compose run --rm tests test/benchmark/bulk_update_request_benchmark.rb
#
# It runs in the test suite's throwaway per-process database, elasticsearch index and redis
# namespace, so development data is never touched. Tuned through environment variables (pass them
# with `docker compose run --rm -e NAME=value tests ...`):
#
#   BUR_BENCH_COMMANDS  comma separated command types to include (default: all, see COMMANDS)
#   BUR_BENCH_MIX       how many command types to combine in one request, e.g. "1,2", or "all" for every combination (default: 1)
#   BUR_BENCH_LINES     lines per request (default: 1,10,25)
#   BUR_BENCH_POSTS     posts per antecedent tag, ignored for commands that don't touch posts (default: 0,10,50)
#   BUR_BENCH_BACKGROUND  unrelated posts to insert first, so queries run against a large posts table (default: 0)
#   BUR_BENCH_INDEX     set to 1 to include elasticsearch indexing in post updates
#   BUR_BENCH_OUTPUT    csv output path (default: tmp/bur_benchmark/<timestamp>.csv)
class BulkUpdateRequestBenchmark < ActiveSupport::TestCase
  # mass update and nuke only process posts in parallel when no transaction is open, and the
  # database gets dropped afterwards anyway
  self.use_transactional_tests = false
  parallelize(workers: 1)

  COMMANDS = {
    alias:       { posts: true,  line: ->(a, b) { "alias #{a} -> #{b}" } },
    imply:       { posts: true,  line: ->(a, b) { "imply #{a} -> #{b}" } },
    unalias:     { posts: false, line: ->(a, b) { "unalias #{a} -> #{b}" } },
    unimply:     { posts: false, line: ->(a, b) { "unimply #{a} -> #{b}" } },
    update:      { posts: true,  line: ->(a, b) { "update #{a} -> #{b}" } },
    nuke:        { posts: true,  line: ->(a, _b) { "nuke #{a}" } },
    rename:      { posts: true,  line: ->(a, b) { "rename #{a} -> #{b}" } },
    category:    { posts: true,  line: ->(a, _b) { "category #{a} -> artist" } },
    deprecate:   { posts: true,  line: ->(a, _b) { "deprecate #{a}" } },
    undeprecate: { posts: false, line: ->(a, _b) { "undeprecate #{a}" } },
  }.freeze

  COLUMNS = %w[background_posts commands lines posts_per_tag setup_s validate_s process_s lines_per_s posts_touched posts_per_s queries sql_s slowest_sql slowest_sql_s status].freeze

  def env_list(name, default)
    ENV.fetch(name, default).split(",").map(&:strip).compact_blank
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def combos
    types = env_list("BUR_BENCH_COMMANDS", COMMANDS.keys.join(",")).map(&:to_sym)
    unknown = types - COMMANDS.keys
    raise(ArgumentError, "unknown commands: #{unknown.join(', ')}") if unknown.any?
    mix = ENV.fetch("BUR_BENCH_MIX", "1")
    sizes = mix == "all" ? (1..types.size).to_a : mix.split(",").map(&:to_i)
    sizes.flat_map { |size| types.combination(size).to_a }
  end

  # copies a post's row (and its version, which later edits expect to exist) once per value in the
  # range, far faster than the factory. tag_string and locked_tags can be overridden with sql
  # expressions, where g is the current value of the range
  def clone_post!(post, range, tag_string: nil, locked_tags: nil)
    return if range.none?
    conn = Post.connection
    columns = Post.column_names - %w[id change_seq]
    overrides = { "tag_string" => tag_string, "locked_tags" => locked_tags }.compact
    values = columns.map { |col| overrides[col] || "posts.#{conn.quote_column_name(col)}" }
    version_columns = PostVersion.column_names - %w[id post_id tags locked_tags]
    conn.execute(<<~SQL.squish)
      WITH new_posts AS (
        INSERT INTO posts (#{columns.map { |col| conn.quote_column_name(col) }.join(', ')})
        SELECT #{values.join(', ')} FROM posts CROSS JOIN generate_series(#{range.first.to_i}, #{range.last.to_i}) AS g
        WHERE posts.id = #{post.id.to_i}
        RETURNING id, tag_string, locked_tags
      )
      INSERT INTO post_versions (post_id, tags, locked_tags, #{version_columns.map { |col| conn.quote_column_name(col) }.join(', ')})
      SELECT new_posts.id, new_posts.tag_string, new_posts.locked_tags, #{version_columns.map { |col| "v.#{conn.quote_column_name(col)}" }.join(', ')}
      FROM new_posts CROSS JOIN (SELECT * FROM post_versions WHERE post_id = #{post.id.to_i} ORDER BY id LIMIT 1) AS v
    SQL
  end

  # ~25 tags from a pool of 20k per post, with locked tags on 1% of them
  def insert_background_posts(count)
    return if count <= 0
    template = create(:post, tag_string: "bur_bg_template", uploader: @uploader)
    tags = "(SELECT string_agg(DISTINCT 'bur_bg_' || ((g::bigint * k * 7919) % 20000), ' ') FROM generate_series(1, 25) AS k)"
    locked = "CASE WHEN g % 100 = 0 THEN 'bur_bg_' || (g % 20000) ELSE '' END"
    (1..count).each_slice(50_000) do |slice|
      clone_post!(template, slice.first..slice.last, tag_string: tags, locked_tags: locked)
      puts("inserted #{slice.last}/#{count} background posts")
    end
    Post.connection.execute("ANALYZE posts")
  end

  def prepare(type, a, b, posts)
    case type
    when :unalias then create(:tag_alias, antecedent_name: a, consequent_name: b, creator: @admin)
    when :unimply then create(:tag_implication, antecedent_name: a, consequent_name: b, creator: @admin)
    when :undeprecate then create(:deprecated_tag, name: a, creator: @admin)
    when :rename then create(:artist_tag, name: a, creator: @admin)
    when :deprecate then create(:wiki_page, title: a, creator: @admin)
    end
    Tag.find_or_create_by_name(a, user: @admin)
    return unless COMMANDS[type][:posts] && posts > 0
    posts = [posts, BulkUpdateRequestCommands::Rename::POST_LIMIT].min if type == :rename
    # every post for a tag is identical, so build one properly and copy it
    post = create(:post, tag_string: "#{a} bur_bench_filler", uploader: @uploader)
    clone_post!(post, 2..posts)
    Tag.where(name: [a, "bur_bench_filler"]).update_all(["post_count = post_count + ?", posts - 1])
  end

  # groups queries that only differ by their values
  def normalize_sql(sql)
    sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\$\d+|\b\d+\b/, "?").gsub(/\(\?(?:, \?)*\)/, "(?)").squish.truncate(160)
  end

  def run_scenario(index, combo, lines, posts)
    prefix = "bur_bench_#{index}"
    setup_started = now
    script = Array.new(lines) do |i|
      type = combo[i % combo.size]
      a = "#{prefix}_#{i}_a"
      b = "#{prefix}_#{i}_b"
      prepare(type, a, b, posts)
      COMMANDS[type][:line].call(a, b)
    end.join("\n")
    setup_time = now - setup_started

    queries = Concurrent::AtomicFixnum.new
    sql_times = Concurrent::Map.new
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
      queries.increment
      sql_times.compute(normalize_sql(event.payload[:sql])) { |total| (total || 0) + event.duration }
    end
    started = now
    db_started = Time.current
    bur = create(:bulk_update_request, script: script, creator: @admin)
    validated = now
    with_inline_jobs { bur.approve!(@admin) }
    finished = now
    ActiveSupport::Notifications.unsubscribe(subscriber)

    process_time = finished - validated
    touched = Post.where(updated_at: db_started..).count
    slowest = sql_times.each_pair.max_by(&:last)
    {
      "background_posts" => @background,
      "commands"         => combo.join("+"),
      "lines"            => lines,
      "posts_per_tag"    => posts,
      "setup_s"          => setup_time.round(3),
      "validate_s"       => (validated - started).round(3),
      "process_s"        => process_time.round(3),
      "lines_per_s"      => (lines / process_time).round(2),
      "posts_touched"    => touched,
      "posts_per_s"      => (touched / process_time).round(2),
      "queries"          => queries.value,
      "sql_s"            => (sql_times.values.sum / 1000).round(3),
      "slowest_sql"      => slowest&.first,
      "slowest_sql_s"    => slowest && (slowest.last / 1000).round(3),
      "status"           => bur.reload.status,
    }
  # errors raised inside inline jobs come back wrapped in Minitest::UnexpectedError
  rescue StandardError, Minitest::UnexpectedError => e
    e = e.error if e.is_a?(Minitest::UnexpectedError)
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    { "background_posts" => @background, "commands" => combo.join("+"), "lines" => lines, "posts_per_tag" => posts, "status" => "#{e.class}: #{e.message.squish}".truncate(120) }
  end

  def print_table(results)
    columns = COLUMNS - %w[slowest_sql] # too wide for a terminal, it's in the csv
    widths = columns.map { |col| [col.size, *results.map { |r| r[col].to_s.size }].max }
    puts(columns.zip(widths).map { |col, w| col.ljust(w) }.join("  ").rstrip)
    results.each { |r| puts(columns.zip(widths).map { |col, w| r[col].to_s.ljust(w) }.join("  ").rstrip) }
  end

  def write_csv(results)
    path = ENV.fetch("BUR_BENCH_OUTPUT") { Rails.root.join("tmp/bur_benchmark/#{Time.now.strftime('%Y%m%d-%H%M%S')}.csv").to_s }
    FileUtils.mkdir_p(File.dirname(path))
    rows = [COLUMNS, *results.map { |r| r.values_at(*COLUMNS) }]
    File.write(path, rows.map { |row| row.map { |v| v.to_s.include?(",") || v.to_s.include?('"') ? %("#{v.to_s.gsub('"', '""')}") : v }.join(",") }.join("\n") << "\n")
    path
  end

  should("measure bulk update request throughput") do
    @admin = create(:admin_user)
    @uploader = create(:user, created_at: 2.weeks.ago)
    AdminConfig.any_instance.stubs(:bur_entry_limit).returns(-1)
    AdminConfig.any_instance.stubs(:bur_nuke).returns(User::Levels::ANONYMOUS)
    Post.any_instance.stubs(:skip_index_update).returns(false) if ENV["BUR_BENCH_INDEX"].to_s.truthy?
    @background = ENV.fetch("BUR_BENCH_BACKGROUND", "0").to_i
    insert_background_posts(@background)

    line_counts = env_list("BUR_BENCH_LINES", "1,10,25").map(&:to_i)
    post_counts = env_list("BUR_BENCH_POSTS", "0,10,50").map(&:to_i)
    scenarios = combos.flat_map do |combo|
      uses_posts = combo.any? { |type| COMMANDS[type][:posts] }
      line_counts.select { |lines| lines >= combo.size }.product(uses_posts ? post_counts : [0]).map { |lines, posts| [combo, lines, posts] }
    end

    run_scenario(0, [:alias], 1, 1) # warm up
    results = scenarios.each_with_index.map do |(combo, lines, posts), index|
      print("[#{index + 1}/#{scenarios.size}] #{combo.join('+')} lines=#{lines} posts=#{posts} ... ")
      result = run_scenario(index + 1, combo, lines, posts)
      puts(result["process_s"] ? "#{result['process_s']}s #{result['status']}" : result["status"])
      result
    end

    puts
    print_table(results)
    puts("\nwrote #{write_csv(results)}")

    assert(results.all? { |r| r["status"] == "approved" }, "some scenarios did not finish as approved, see the status column")
  end
end
