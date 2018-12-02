module Jets::Gems
  class Agree
    def initialize
      @agree_file = "#{ENV['HOME']}/.jets/agree"
    end

    # Only prompts if hasnt prompted before and saved a ~/.jets/agree file
    def prompt
      return if File.exist?(@agree_file)

      puts "The Jets project contains binary gems that are not yet available in your gems source. You can help make Jets and the community better by reporting the missing binary gems.  Reported gems get built more quickly.  BoltOps takes privacy seriously and only collects anonymous non-identifiable data. You will only be asked this once."
      puts "Do you want send reporting data to BoltOps? (Y/n)?"
      answer = $stdin.gets.strip
      value = answer =~ /y/i ? 'yes' : 'no'

      FileUtils.mkdir_p(File.dirname(@agree_file))
      IO.write(@agree_file, value)
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
