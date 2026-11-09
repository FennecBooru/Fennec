#!/usr/bin/env ruby
# frozen_string_literal: true

require(File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment")))

# Renames the site in the admin config and the wiki as if it always had the new name: wiki pages and every one of
# their versions are changed in place, without new versions. Titles aren't changed since other things link to them.
#
#   OLD_NAME="Old Site" NEW_NAME="New Site" OLD_URL=https://old.example NEW_URL=https://new.example db/fixes/change_site_name.rb
#
# Either pair can be left out. The url's host is replaced too, for links without a scheme and email addresses.
# DRY_RUN=1 lists what would change without changing it.

dry_run = ENV.fetch("DRY_RUN", "").truthy?
old_name, new_name, old_url, new_url = %w[OLD_NAME NEW_NAME OLD_URL NEW_URL].map { |key| ENV.fetch(key, "").strip }
replacements = []

if old_name.present? || new_name.present?
  abort("OLD_NAME and NEW_NAME are both needed") if old_name.blank? || new_name.blank?
  # only the whole name, and not in url paths, so a name like Fennec doesn't change github.com/FennecBooru/Fennec
  replacements << [old_name, %r{(?<![\w/])#{Regexp.escape(old_name)}(?!\w)}, new_name]
end

if old_url.present? || new_url.present?
  abort("OLD_URL and NEW_URL are both needed") if old_url.blank? || new_url.blank?
  old_url = old_url.chomp("/")
  new_url = new_url.chomp("/")
  old_host = URI(old_url).host
  new_host = URI(new_url).host
  abort("OLD_URL and NEW_URL need to be full urls, like https://example.com") if old_host.blank? || new_host.blank?
  # the full url first, it contains the host
  replacements << [old_url, /#{Regexp.escape(old_url)}/, new_url]
  replacements << [old_host, /(?<![\w.-])#{Regexp.escape(old_host)}(?![\w-])/, new_host]
end

abort("Give OLD_NAME and NEW_NAME, OLD_URL and NEW_URL, or both") if replacements.empty?

# the block form so a replacement containing \1 isn't treated as a backreference
replace = ->(text) { replacements.reduce(text) { |result, (_, pattern, new)| result.gsub(pattern) { new } } }
needles = replacements.map(&:first).uniq
containing = ->(relation) { relation.where(needles.map { "body LIKE ?" }.join(" OR "), *needles.map { |n| "%#{relation.sanitize_sql_like(n)}%" }) }

puts("Dry run, nothing will be changed") if dry_run
puts("Replacing: #{replacements.map { |(old, _, new)| "#{old} -> #{new}" }.join(', ')}")

ApplicationRecord.transaction do
  # every row, the defaults too
  AdminConfig.all.to_a.each do |config|
    changes = config.attributes.except("id").filter_map do |name, value|
      next unless value.is_a?(String)
      replaced = replace.call(value)
      [name, replaced] if replaced != value
    end.to_h
    next if changes.empty?
    puts("Admin config #{config.id}: #{changes.keys.join(', ')}")
    config.update_columns(changes) unless dry_run
  end

  pages = 0
  containing.call(WikiPage.all).find_each do |page|
    body = replace.call(page.body)
    next if body == page.body
    pages += 1
    puts("Wiki page #{page.title}") if dry_run
    next if dry_run
    old_body = page.body
    page.update_columns(body: body)
    page.update_dtext_links if DTextHelper.dtext_links_differ?(body, old_body)
  end
  puts("Updated #{pages} wiki #{'page'.pluralize(pages)}")

  versions = 0
  containing.call(WikiPageVersion.all).find_each do |version|
    body = replace.call(version.body)
    next if body == version.body
    versions += 1
    version.update_columns(body: body) unless dry_run
  end
  puts("Updated #{versions} wiki page #{'version'.pluralize(versions)}")
end

AdminConfig.delete_cache unless dry_run
