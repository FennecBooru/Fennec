# frozen_string_literal: true

require_relative("../../app/logical/reports")

if Reports.configured?
  ClickHouse.config do |config|
    config.url = Fennec.config.clickhouse_url
  end
end
