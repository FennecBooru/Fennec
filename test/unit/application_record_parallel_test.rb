# frozen_string_literal: true

require("test_helper")

class ApplicationRecordParallelTest < ActiveSupport::TestCase
  # parallel_find_each runs serially when a transaction is open
  self.use_transactional_tests = false

  context("ApplicationRecord.parallel_find_each") do
    setup do
      @tags = create_list(:tag, ActiveRecord::Base.connection_pool.size * 3)
    end

    teardown do
      TagVersion.where(tag_id: @tags.map(&:id)).delete_all
      Tag.where(id: @tags.map(&:id)).delete_all
    end

    should("return connections leased by the block") do
      seen = Concurrent::Array.new
      Tag.where(id: @tags.map(&:id)).parallel_find_each do |tag|
        Tag.lease_connection.select_value("SELECT 1")
        sleep(0.05)
        seen << tag.id
      end

      assert_equal(@tags.map(&:id).sort, seen.sort)
    end
  end
end
