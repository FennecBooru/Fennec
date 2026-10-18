#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

client = Post.document_store.client
client.indices.put_mapping(index: Post.document_store.index_name, body: {
  dynamic_templates: [{ tag_category_counts: { path_match: "tag_category_counts.*", mapping: { type: "integer" } } }],
  properties:        { tag_category_counts: { type: "object", dynamic: true } },
})
