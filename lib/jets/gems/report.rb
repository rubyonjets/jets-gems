require "net/http"

module Jets::Gems
  class Report
    # For local testing, example:
    #   LAMBDAGEM_API_URL=localhost:8888/api/v1 jets gems:check
    LAMBDAGEM_API_URL = ENV["LAMBDAGEM_API_URL"] || "https://api.lambdagems.com/api/v1"

    def self.missing(gems)
      new(gems).report
    end

    def initialize(gems)
      @gems = gems
    end

    def report
      version_pattern = /(.*)-(\d+\.\d+\.\d+.*)/
      threads = []
      @gems.each do |gem_name|
        if md = gem_name.match(version_pattern)
          name, version = md[1], md[2]
          threads << Thread.new do
            call_api("report/missing?name=#{name}&version=#{version}", async: true)
          end
        else
          puts "WARN: Unable to extract the version from the gem name."
        end
      end
      # Wait for request to finish because the command might finish before
      # the Threads even send the request. So we join them just case
      threads.each(&:join)
    end

    def api_url(path)
      url = "#{LAMBDAGEM_API_URL}/#{path}"
      url.include?("http") ? url : "http://#{url}" # ensure http or https has been provided
    end

    def call_api(path, async: false)
      uri = URI(api_url(path))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      # Abusing read_timeout to mimic async fire and forget behavior.
      # This makes the code continue and return very quickly and we ignore the response
      # Thanks: https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/
      # https://github.com/ankane/the-ultimate-guide-to-ruby-timeouts/issues/8
      http.max_retries = 0 # Fix http retries, read_timeout will cause retries immediately, we want to disable this behavior
      http.read_timeout = 0.01 if async
      request = Net::HTTP::Get.new(uri)
      begin
        response = http.request(request)
      rescue Net::ReadTimeout
        # Abusing read_timeout to mimic async fire and forget behavior
      end
      return nil if async # always return nil if async behavior requested.
        # In theory we can sometimes get back a response if it returns before
        # the read timeout but that's a confusing interface.

      resp = {
        status: response.code.to_i,
        headers: response.each_header.to_h,
        body: response.body,
      }
      # pp resp # Uncomment to debug
      resp
    end
  end
end
