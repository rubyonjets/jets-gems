# Assumes gems were just built and checks the filesystem to find and detect for
# compiled gems.  Unless the cli option is set to true, the it'll just check
# based on the gemspecs.
module Jets::Gems
  class Check
    extend Memoist

    attr_reader :missing_gems
    def initialize(options={})
      @options = options
      @missing_gems = [] # keeps track of gems that are not found in any of the lambdagems sources
    end

    def run!
      run(exit_early: true)
    end

    # Checks whether the gem is found on at least one of the lambdagems sources.
    # By the time the loop finishes, found_gems will hold a map of gem names to found
    # url sources. Example:
    #
    #   found_gems = {
    #     "nokogiri-1.8.4" => "https://lambdagems.com",
    #     "pg-0.21.0" => "https://anothersource.com",
    #   }
    #
    def run(exit_early: false)
      puts "Checking projects gems for binary Lambda gems..."
      found_gems = {}
      compiled_gems.each do |gem_name|
        puts "Checking #{gem_name}..." if @options[:cli]
        gem_exists = false
        Jets.config.gems.sources.each do |source|
          exist = Jets::Gems::Exist.new(source_url: source)
          found = exist.check(gem_name)
          # gem exists on at least of the lambdagem sources
          if found
            gem_exists = true
            found_gems[gem_name] = source
            break
          end
        end
        unless gem_exists
          @missing_gems << gem_name
        end
      end

      if exit_early && !@missing_gems.empty?
        # Exits early if not all the linux gems are available.
        # Better to error now than deploy a broken package to AWS Lambda.
        # Provide users with message about using their own lambdagems source.
        puts missing_message
        Report.missing(@missing_gems) if agree.yes?
        exit 1
      end

      found_gems
    end

    def missing?
      !@missing_gems.empty?
    end

    def missing_message
      template = <<-EOL
Your project requires compiled gems were not available in any of your lambdagems sources.  Unavailable pre-compiled gems:
<% missing_gems.each do |gem| %>
* <%= gem -%>
<% end %>

Your current lambdagems sources:
<% Jets.config.gems.sources.map do |source| %>
* <%= source -%>
<% end %>

Jets is unable to build a deployment package that will work on AWS Lambda without the required pre-compiled gems. To remedy this, you can:

* Use another gem that does not require compilation.
* Create your own custom layer with the gem: http://rubyonjets.com/docs/extras/custom-lambda-layers/
<% if agree.yes? -%>
* No need to report this to us, as we've already been notified.
<% elsif agree.no? -%>
* You have choosen not to report data to lambdagems so we will not be notified about these missing gems.  You can edit ~/.jets/agree to change this.
* Reporting gems generally allows Lambdagems to build the missing gems within a few minutes.
* You can try redeploying again after a few minutes.
* Non-reported gems may take days or even longer to be built.
<% end -%>

Compiled gems usually take some time to figure out how to build as they each depend on different libraries and packages.
More info: http://rubyonjets.com/docs/lambdagems/

EOL
      erb = ERB.new(template, nil, '-') # trim mode https://stackoverflow.com/questions/4632879/erb-template-removing-the-trailing-line
      erb.result(binding)
    end

    def agree
      Agree.new
    end
    memoize :agree

    # Context, observations, and history:
    #
    # Two ways to check if gem is compiled.
    #
    #     1. compiled_gem_paths - look for .so and .bundle extension files in the folder itself.
    #     2. gemspec - uses the gemspec metadata.
    #
    # Observations:
    #
    #     * The gemspec approach generally finds more compiled gems than the compiled_gem_paths approach.
    #     * So when using the compiled_gem_paths some compiled are missed and not properly detected like http-parser.
    #     * However, some gemspec found compiled gems like json are weird and they don't work when they get replaced.
    #
    # History:
    #
    #     * Started with compiled_gem_paths approach
    #     * Tried to gemspec approach, but ran into json-2.1.0 gem issues. bundler removes? http://bit.ly/39T8uln
    #     * Went to selective checking approach with `cli: true` option. This helped gather more data.
    #       * jets deploy - compiled_gem_paths
    #       * jets gems:check - gemspec_compiled_gems
    #     * Going back to compiled_gem_paths with.
    #       * Using the `weird_gem?` check to filter out gems removed by bundler. Note: Only happens with specific versions of json.
    #       * Removed compiled_gem_paths and compiled_gem_paths methods. Can get it from git history if needed again.
    #
    def compiled_gems
      gemspec_compiled_gems
    end

    # So can also check for compiled gems with Gem::Specification
    # But then also includes the json gem, which then bundler removes?
    # We'll figure out the the json gems.
    # https://gist.github.com/tongueroo/16f4aa5ac5393424103347b0e529495e
    #
    # This is a faster way to check but am unsure if there are more gems than just
    # json that exhibit this behavior. So only using this technique for this commmand:
    #
    #   jets gems:check
    #
    # Thanks: https://gist.github.com/aelesbao/1414b169a79162b1d795 and
    #   https://stackoverflow.com/questions/5165950/how-do-i-get-a-list-of-gems-that-are-installed-that-have-native-extensions
    def gemspec_compiled_gems
      specs = Gem::Specification.each.select { |spec| spec.extensions.any?  }
      specs.reject! { |spec| weird_gem?(spec.name) }
      specs.map(&:full_name)
    end

    # Filter out the weird special case gems that bundler deletes?
    # Probably to fix some bug.
    #
    #   $ bundle show json
    #   The gem json has been deleted. It was installed at:
    #   /home/ec2-user/.rbenv/versions/2.5.1/lib/ruby/gems/2.5.0/gems/json-2.1.0
    #
    def weird_gem?(name)
      command = "bundle show #{name} 2>&1"
      output = `#{command}`
      output.include?("has been deleted")
    end
  end
end