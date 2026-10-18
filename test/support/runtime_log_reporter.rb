# frozen_string_literal: true

require("minitest/reporters")

# Writes how long each test file took, one "path:seconds" per line. CI uses it to split the
# files across jobs, see bin/test-shard
class RuntimeLogReporter < Minitest::Reporters::BaseReporter
  def initialize(path)
    super()
    @path = path
    @times = Hash.new(0.0)
  end

  def record(result)
    super
    # the file the class is defined in, the test's own location can be a helper that generates tests
    file = Object.const_source_location(result.klass)&.first
    @times[Pathname(file).relative_path_from(Rails.root).to_s] += result.time if file
  end

  def report
    super
    FileUtils.mkdir_p(File.dirname(@path))
    File.write(@path, @times.sort.map { |file, time| "#{file}:#{time.round(3)}\n" }.join)
  end
end
