#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

requires_migration!(20261014031322)

BATCH_SIZE = 1000

# done in sql so the Post model isn't loaded, it can't be while the old TagCategory is around
conn = ActiveRecord::Base.connection
max_id = conn.select_value("SELECT MAX(id) FROM posts").to_i
total = (max_id / BATCH_SIZE.to_f).ceil
count = 0
puts("Batch size: #{BATCH_SIZE} | Total Batches: #{total}")
(0...total).each do |index|
  from = (index * BATCH_SIZE) + 1
  to = from + BATCH_SIZE - 1
  puts("Batch #{index + 1}/#{total}: #{from}-#{to}")
  # disabled per batch inside a transaction so other sessions never see the trigger off
  conn.transaction do
    conn.execute("ALTER TABLE posts DISABLE TRIGGER posts_update_change_seq")
    count += conn.exec_update(<<~SQL.squish)
      UPDATE posts SET tag_category_data = (
        SELECT jsonb_object_agg(category, count) FROM (
          SELECT split_part(t, '|', 1) AS category, COUNT(*) AS count
          FROM unnest(string_to_array(typed_tag_string, ' ')) AS t
          GROUP BY 1
        ) counts
      )
      WHERE id BETWEEN #{from} AND #{to} AND typed_tag_string != ''
    SQL
    conn.execute("ALTER TABLE posts ENABLE TRIGGER posts_update_change_seq")
  end
end
puts("Backfilled tag_category_data for #{count} posts")
