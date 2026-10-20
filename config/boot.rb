# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Fallback for environments still using the old GAYFURCITY_ prefix
ENV.keys.grep(/\AGAYFURCITY_/).each { |key| ENV[key.sub("GAYFURCITY_", "FENNEC_")] ||= ENV.fetch(key) }

require("bundler/setup") # Set up gems listed in the Gemfile.
require("bootsnap/setup") # Speed up boot time by caching expensive operations.
