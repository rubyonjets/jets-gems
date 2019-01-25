require "open-uri"

module Jets::Gems::Extract
  class Base
    class NotFound < RuntimeError; end

    attr_reader :source_url
    def initialize(name, options={})
      @name = name
      @options = options

      @downloads_root = options[:downloads_root] || "/tmp/jets/#{Jets.config.project_name}/lambdagems"
      @source_url = options[:source_url] || Jets.default_gems_source
    end

    def clean_downloads(folder)
      path = "#{@downloads_root}/downloads/#{folder}"
      say "Removing cache: #{path}"
      FileUtils.rm_rf(path)
    end

    def unzip(zipfile_path, parent_folder_dest)
      sh("cd #{parent_folder_dest} && unzip -qo #{zipfile_path}")
    end

    def sh(command)
      say "=> #{command}".color:green)
      success = system(command)
      abort("Command Failed") unless success
      success
    end

    def url_exists?(url)
      exist = Jets::Gems::Exist.new(@options)
      exist.url_exists?(url)
    end

    # Returns the dest path
    def download_file(source_url, dest)
      say "Url #{source_url}"
      return unless url_exists?(source_url)

      if File.exist?(dest)
        say "File already downloaded #{dest}"
        return dest
      end

      say "Downloading..."
      FileUtils.mkdir_p(File.dirname(dest)) # ensure parent folder exists

      File.open(dest, 'wb') do |saved_file|
        open(source_url, 'rb') do |read_file|
          saved_file.write(read_file.read)
        end
      end
      dest
    end

    def project_root
      @options[:project_root] || "."
    end

    @@log_level = :info # default level is :info
    # @@log_level = :debug # uncomment to debug
    def log_level=(val)
      @@log_level = val
    end

    def say(message, level=:info)
      enabled = @@log_level == :debug || level == :debug
      puts(message) if enabled
    end
  end
end
