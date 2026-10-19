# frozen_string_literal: true

require("test_helper")

module Downloads
  class FileTest < ActiveSupport::TestCase
    def assert_correct_escaping(input, output)
      file = Downloads::File.new(input)

      assert_equal(file.url.to_s, output)

      # Validate that no double-encoding is going on
      file = Downloads::File.new(file.url.to_s)

      assert_equal(file.url.to_s, output)
    end

    context("A post download that is whitelisted") do
      setup do
        CloudflareService.stubs(:ips).returns([])
        create(:upload_whitelist, pattern: "https://example.com/*")
      end

      should("not follow redirects to non-whitelisted domains") do
        stub_request(:get, "https://example.com/file.png").to_return(status: 301, headers: { location: "https://gayfur.city/abc" })
        error = assert_raises(Downloads::File::Error) do
          Downloads::File.new("https://example.com/file.png").download!
        end
        assert_match("'https://gayfur.city/abc' is not whitelisted", error.message)
      end
    end

    context("A post download") do
      setup do
        CloudflareService.stubs(:ips).returns([])
        create(:upload_whitelist, pattern: "*")
      end

      context("for a banned IP") do
        setup do
          Addrinfo.expects(:getaddrinfo).returns([Addrinfo.tcp("127.0.0.1", 0)]).at_least_once
        end

        should("not try to download the file") do
          error = assert_raises(Downloads::File::Error) do
            Downloads::File.new("http://evil.com").download!
          end
          assert_match("from 127.0.0.1 are not", error.message)
        end

        should("not follow redirects to banned IPs") do
          url = "http://httpbin.org/redirect-to?url=http://127.0.0.1"
          stub_request(:get, url).to_return(status: 301, headers: { location: "http://127.0.0.1" })

          error = assert_raises(Downloads::File::Error) do
            Downloads::File.new(url).download!
          end
          assert_match("from 127.0.0.1 are not", error.message)
        end

        should("not follow redirects that resolve to a banned IP") do
          url = "http://httpbin.org/redirect-to?url=http://127.0.0.1.nip.io"
          stub_request(:get, url).to_return(status: 301, headers: { location: "http://127.0.0.1.xip.io" })

          error = assert_raises(Downloads::File::Error) do
            Downloads::File.new(url).download!
          end
          assert_match("from 127.0.0.1 are not", error.message)
        end
      end

      context("address checks") do
        should("block internal and reserved addresses") do
          %w[127.0.0.1 10.0.0.1 172.16.0.1 192.168.1.1 169.254.169.254 0.0.0.0 100.64.0.1 192.0.0.1 198.18.0.1 224.0.0.1 255.255.255.255
             ::1 :: fd00::1 fe80::1 ff02::1 ::ffff:127.0.0.1 ::ffff:169.254.169.254 ::127.0.0.1 64:ff9b::a00:1 2001:db8::1].each do |ip|
            assert(Downloads::File.blocked_address?(IPAddr.new(ip)), "#{ip} should be blocked")
          end
        end

        should("allow public addresses") do
          %w[93.184.216.34 1.1.1.1 2606:4700:4700::1111 ::ffff:93.184.216.34].each do |ip|
            assert_not(Downloads::File.blocked_address?(IPAddr.new(ip)), "#{ip} should be allowed")
          end
        end

        should("block a host if any of its addresses are internal") do
          Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("93.184.216.34", 0), Addrinfo.tcp("10.0.0.1", 0)])

          error = assert_raises(Downloads::File::Error) { Downloads::File.new("https://example.com/file.png") }
          assert_match("from 10.0.0.1 are not", error.message)
        end

        should("block hosts that don't resolve") do
          Addrinfo.stubs(:getaddrinfo).raises(SocketError)

          error = assert_raises(Downloads::File::Error) { Downloads::File.new("https://example.com/file.png") }
          assert_match("Couldn't resolve", error.message)
        end

        should("connect to the address that was checked") do
          Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("93.184.216.34", 0)])
          stub_request(:get, "https://example.com/file.png").to_return(body: "abc")
          Net::HTTP.any_instance.expects(:ipaddr=).with("93.184.216.34")

          assert_equal("abc", Downloads::File.new("https://example.com/file.png").download!.read)
        end

        should("not connect if the host resolves somewhere else after it was checked") do
          Addrinfo.stubs(:getaddrinfo).returns([Addrinfo.tcp("93.184.216.34", 0)]).then.returns([Addrinfo.tcp("127.0.0.1", 0)])
          request = stub_request(:get, "https://example.com/file.png").to_return(body: "abc")
          download = Downloads::File.new("https://example.com/file.png")

          error = assert_raises(Downloads::File::Error) { download.download! }
          assert_match("from 127.0.0.1 are not", error.message)
          assert_not_requested(request)
        end
      end

      context("that fails") do
        should("retry three times before giving up") do
          download = Downloads::File.new("https://example.com/1")
          stub_request(:get, "https://example.com/1").to_raise(Errno::ETIMEDOUT).times(2).then.to_return(body: "foo")

          assert_equal("foo", download.download!.read)

          download = Downloads::File.new("https://example.com/2")
          stub_request(:get, "https://example.com/2").to_raise(Errno::ETIMEDOUT).times(3)
          assert_raises(Faraday::Error) { download.download! }
        end

        should("return an uncorrupted file on the second try") do
          source = "https://example.com"
          download = Downloads::File.new(source)
          stub_request(:get, source).to_raise(Errno::ETIMEDOUT).then.to_return(body: "abc")

          tempfile = download.download!

          assert_equal("abc", tempfile.read)
        end

        should("raise for 404") do
          stub_request(:get, "https://example.com").to_return(status: 404)
          download = Downloads::File.new("https://example.com")
          e = assert_raises(Downloads::File::Error) { download.download! }
          assert_match("Not Found", e.message)
        end
      end

      should("throw an exception when the file is larger than the maximum") do
        source = "https://example.com"
        download = Downloads::File.new(source)
        stub_request(:get, source).to_return(body: "body")
        assert_raises(Downloads::File::Error) do
          download.download!(max_size: 1)
        end
      end

      should("store the file in the tempfile path") do
        source = "https://example.com"
        download = Downloads::File.new(source)
        stub_request(:get, source).to_return(body: "body")

        tempfile = download.download!

        assert_equal("body", tempfile.read)
      end

      should("correctly follow redirects") do
        redirect_url = "https://example.com/redirected"
        initial_request = stub_request(:get, "https://example.com").to_return(body: "Your are being redirected", status: 302, headers: { location: redirect_url })
        redirect_request = stub_request(:get, redirect_url).to_return(body: "Actual content")

        file = Downloads::File.new("https://example.com").download!

        assert_requested(initial_request)
        assert_requested(redirect_request)
        assert_equal("Actual content", file.read)
      end

      context("url normalization") do
        should("correctly escapes cyrilic characters") do
          input = "https://d.furaffinity.net/art/peyzazhik/1629082282/1629082282.peyzazhik_заливать-гитару.jpg"
          output = "https://d.furaffinity.net/art/peyzazhik/1629082282/1629082282.peyzazhik_%D0%B7%D0%B0%D0%BB%D0%B8%D0%B2%D0%B0%D1%82%D1%8C-%D0%B3%D0%B8%D1%82%D0%B0%D1%80%D1%83.jpg"

          assert_correct_escaping(input, output)
        end

        should("correctly escapes square brackets") do
          input = "https://d.furaffinity.net/art/kinniro/1461084939/1461084939.kinniro_[commission]41.png"
          output = "https://d.furaffinity.net/art/kinniro/1461084939/1461084939.kinniro_%5Bcommission%5D41.png"

          assert_correct_escaping(input, output)
        end

        should("correctly escapes ＠") do
          input = "https://d.furaffinity.net/art/fr95/1635001690/1635001679.fr95_co＠f-r9512.png"
          output = "https://d.furaffinity.net/art/fr95/1635001690/1635001679.fr95_co%EF%BC%A0f-r9512.png"

          assert_correct_escaping(input, output)
        end
      end
    end
  end
end
