require "net/http"

module Jets::Gems
  class Report
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
            call_api("report/missing?name=#{name}&version=#{version}")
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
      "#{LAMBDAGEM_API_URL}/#{path}"
    end

    def call_api(path)
      # raise "HI"
      uri = URI(api_url(path))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
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
