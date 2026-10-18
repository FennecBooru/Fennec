# frozen_string_literal: true

require "dtext/dtext"
require "dtext/version"

begin
  require "zeitwerk"

  loader = Zeitwerk::Loader.for_gem
  loader.enable_reloading
  loader.inflector.inflect("dtext" => "DText")
  #loader.logger = Logger.new(STDERR)
  loader.setup
rescue LoadError
end

class DText
  class Error < StandardError; end

  # The names [color=name] has always accepted, used when color_names isn't given
  DEFAULT_COLOR_NAMES = %w[general gen artist art contributor cont copyright copy co character char ch oc species spec invalid inv meta lore lor gender important imp].freeze

  def self.parse(str, inline: false, disable_mentions: false, allow_color: false, qtags: false, max_thumbs: 25, base_url: nil, domain: nil, internal_domains: [], color_names: DEFAULT_COLOR_NAMES, github_url: nil)
    c_parse(str, base_url, domain, internal_domains, color_names, github_url, inline, disable_mentions, allow_color, qtags, max_thumbs)
  end
end
