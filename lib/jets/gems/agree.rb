module Jets::Gems
  class Agree
    def initialize
      @agree_file = "#{ENV['HOME']}/.jets/agree"
    end

    # Only prompts if hasnt prompted before and saved a ~/.jets/agree file
    def prompt
      return if bypass_prompt
      return if File.exist?(@agree_file)

      puts <<~EOL
        Jets sends data about your gems to your specified lambda build service **lambdagems.com** so that it can compile and generate the necessary Lambda layers.

        Reporting gems generally allows Lambdagems to build new gems within few minutes. So if you run into missing gems, you can try deploying again after a few minutes. Non-reported gems may take several days or longer.

        Lambdagems only collects anonymous non-identifiable data.

        Is it okay to send your gem data to Lambdagems? (Y/n)?
      EOL

      answer = $stdin.gets.strip
      value = answer =~ /y/i ? 'yes' : 'no'

      write_file(value)
    end

    # Allow user to bypass prompt with JETS_AGREE=1 JETS_AGREE=yes etc
    # Useful for CI/CD pipelines.
    def bypass_prompt
      agree = ENV['JETS_AGREE']
      return false unless agree

      if %w[1 yes true].include?(agree.downcase)
        write_file('yes')
      else
        write_file('no')
      end

      true
    end

    def yes?
      File.exist?(@agree_file) && IO.read(@agree_file).strip == 'yes'
    end

    def no?
      File.exist?(@agree_file) && IO.read(@agree_file).strip == 'no'
    end

    def yes!
      write_file("yes")
    end

    def no!
      write_file("no")
    end

    def write_file(content)
      FileUtils.mkdir_p(File.dirname(@agree_file))
      IO.write(@agree_file, content)
    end
  end
end
