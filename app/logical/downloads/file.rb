# frozen_string_literal: true

require("resolv")
require("ipaddr")

module Downloads
  class File
    include(ActiveModel::Validations)

    class Error < StandardError; end

    # addresses downloads can't connect to, on top of IPAddr's private, loopback, and link local checks
    BLOCKED_RANGES = %w[
      0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
      ::/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 2001:db8::/32 ff00::/8
    ].map { |range| IPAddr.new(range) }.freeze

    attr_reader(:user, :url)

    validate(:validate_url)

    def initialize(url, exception: true, user: User.anonymous)
      @user = user
      begin
        unencoded = Addressable::URI.unencode(url)
        escaped = Addressable::URI.escape(unencoded)
        @url = Addressable::URI.parse(escaped)
      rescue Addressable::URI::InvalidURIError
        @url = nil
      end
      if exception
        validate!
      else
        validate
      end
    end

    def download!(max_size: nil, retries: 3)
      # default arguments are evaluated when the method is defined
      max_size ||= AdminConfig.instance.max_file_size * 1.megabyte
      file = Tempfile.new(binmode: true)
      conn = Faraday.new(GayFurCity.config.faraday_options) do |f|
        f.response(:follow_redirects, callback: ->(_old_env, new_env) { validate_uri_allowed!(new_env.url) })
        f.request(:retry, max: retries, retry_block: ->(*) { file = Tempfile.new(binmode: true) })
        # connect to the address that was checked, so the host can't resolve somewhere else in between
        f.adapter(:net_http) { |http| http.ipaddr = self.class.public_address!(http.address) }
      end

      res = conn.get(uncached_url, nil, strategy.headers) do |req|
        req.options.on_data = ->(chunk, overall_recieved_bytes, env) do
          next if [301, 302].include?(env.status)

          raise(Error, "File is too large (max size: #{max_size})") if overall_recieved_bytes > max_size
          file.write(chunk)
        end
      end
      raise(Error, "HTTP error code: #{res.status} #{Rack::Utils::HTTP_STATUS_CODES[res.status]}") unless res.success?

      file.rewind
      file
    end

    def validate_url
      errors.add(:base, "URL must not be blank") if url.blank?
      errors.add(:base, "'#{url}' is not a valid url") if url.host.blank?
      errors.add(:base, "'#{url}' is not a valid url. Did you mean 'http://#{url}'?") unless url.scheme.in?(%w[http https])
      validate_uri_allowed!(url)
    end

    # Prevent Cloudflare from potentially mangling the image. See issue #3528.
    def uncached_url
      return file_url unless is_cloudflare?(file_url)

      url = file_url.dup
      url.query_values = url.query_values.to_h.merge(no_cache: SecureRandom.uuid)
      url
    end

    def file_url
      @file_url ||= Addressable::URI.parse(strategy.image_url)
    end

    def strategy
      @strategy ||= Sources::Strategies.find(url.to_s)
    end

    def is_cloudflare?(url)
      # noinspection RubyArgCount
      ip_addr = IPAddr.new(Resolv.getaddress(url.hostname))
      CloudflareService.ips.any? { |subnet| subnet.include?(ip_addr) }
    end

    def self.blocked_address?(ip)
      ip = ip.native # ipv4 mapped ipv6 addresses are checked as ipv4
      ip.private? || ip.loopback? || ip.link_local? || BLOCKED_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
    end

    # every address the host resolves to has to be public, returns the one to connect to
    def self.public_address!(host)
      addresses = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map { |info| IPAddr.new(info.ip_address) }.uniq
      raise(Error, "Couldn't resolve #{host}") if addresses.empty?
      blocked = addresses.find { |ip| blocked_address?(ip) }
      raise(Error, "Downloads from #{blocked} are not allowed") if blocked
      addresses.first.to_s
    rescue SocketError, IPAddr::InvalidAddressError
      raise(Error, "Couldn't resolve #{host}")
    end

    def validate_uri_allowed!(uri)
      self.class.public_address!(uri.hostname)

      valid, _reason = UploadWhitelist.is_whitelisted?(uri, user)
      unless valid
        raise(Downloads::File::Error, "'#{uri}' is not whitelisted and can't be direct downloaded")
      end
    end
  end
end
