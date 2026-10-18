#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

# Only for after 20261014031322 has been rolled back, which re-adds the tag_count_* columns empty.
# Does nothing otherwise, since the columns don't exist.

ID_MAP = {
  0  => "general",
  1  => "artist",
  2  => "contributor",
  3  => "copyright",
  4  => "character",
  5  => "species",
  6  => "invalid",
  7  => "meta",
  8  => "lore",
  9  => "gender",
  10 => "important",
}.freeze
BATCH_SIZE = 1000

conn = ActiveRecord::Base.connection
unless conn.column_exists?(:posts, :tag_count_general)
  puts("tag_count_* columns don't exist, nothing to restore")
  return
end

sets = ID_MAP.map do |id, name|
  "tag_count_#{name} = (SELECT COUNT(*) FROM unnest(string_to_array(typed_tag_string, ' ')) AS t WHERE split_part(t, '|', 1) = '#{id}')"
end
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
    count += conn.exec_update("UPDATE posts SET #{sets.join(', ')} WHERE id BETWEEN #{from} AND #{to} AND typed_tag_string != ''")
    conn.execute("ALTER TABLE posts ENABLE TRIGGER posts_update_change_seq")
  end
end
puts("Restored tag counts for #{count} posts")
