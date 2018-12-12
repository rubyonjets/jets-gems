# Usage:
#
#   Jets::Gems::Extract::Ruby.new("2.5.3",
#     downloads_root: cache_area, # defaults to /tmp/lambdagem
#     dest: cache_area, # defaults to . (project_root)
#   ).run
#
module Jets::Gems::Extract
  class Ruby < Base
    class NotFound < RuntimeError; end

    def run
      say "Looking for #{full_ruby_name}"
      clean_downloads(:rubies) if @options[:clean]
      zip_path = download_ruby
      unzip(zip_path)
    end

    def unzip(path)
      dest = "#{Jets.build_root}/stage/code/opt"
      say "Unpacking into #{dest}"
      FileUtils.mkdir_p(dest)
      # cd-ing dest unzips the files into that folder
      sh("cd #{dest} && unzip -qo #{path}")
      say("Ruby #{full_ruby_name} unziped at #{dest}", :debug)
    end

    def download_ruby
      url = ruby_url
      puts "download ruby url #{url}"
      tarball_dest = download_file(url, download_path(File.basename(url)))
      unless tarball_dest
        message = "Url: #{url} not found"
        if @options[:exit_on_error]
          say message
          exit
        else
          raise NotFound.new(message)
        end
      end
      say "Downloaded to: #{tarball_dest}"
      tarball_dest
    end

    def download_path(filename)
      "#{@downloads_root}/downloads/rubies/#{filename}"
    end

    # If only the ruby version is given, then append ruby- in front. Otherwise
    # leave alone.
    #
    # Example:
    #
    #    2.5.3           -> ruby-2.5.3.zip
    #    ruby-2.5.3      -> ruby-2.5.3.zip
    #    test-ruby-2.5.3 -> test-ruby-2.5.3.zip
    def full_ruby_name
      md = @name.match(/^(\d+\.\d+\.\d+)$/)
      if md
        ruby_version = md[1]
        "ruby-#{ruby_version}.zip"
      else
        "#{@name}.zip"
      end
    end

    def ruby_url
      "#{source_url}/rubies/#{full_ruby_name}"
    end
  end
end
