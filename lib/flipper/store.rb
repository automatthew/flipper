class Flipper

  class Store

    attr_reader :completions, :base_file
    # Create or use a configuration storage structure in the supplied
    # directory.  Creates the directory if it does not already
    # exist.  Will load existing storage data (previous config state,
    # as well as a tab-completion dictionary).
    def initialize(directory)
      @dir = File.expand_path(directory)
      FileUtils.mkdir_p(@dir)
      @base_file = "#{directory}/_base.json"
      @completions_file = "#{directory}/_comp.json"
      self.load
    end

    # If the missing method is defined on the config object, relay it
    # thenceward.
    def method_missing(name, *args)
      @config.respond_to?(name) ? @config.send(name, *args) : super
    end

    # Assuming they exist, read the last-state and completions JSON
    # files.  Otherwise, magick up suitable defaults.
    def load
      if File.exist?(@base_file)
        string = File.read(@base_file)
        obj = JSON.parse(string)
      else
        obj = {
        "target" => {},
        "tester" => {
          "software" => "dolphin",
          "version" => 0.1,
        },
        "human" => "anonymous coward"
        }
      end
      @config = HashTree[obj]

      if File.exist?(@completions_file)
        string = File.read(@completions_file)
        obj = JSON.parse(string)
      else
        obj = []
      end
      @completions = Set.new(obj)

      # in case there were manual edits to the file,
      # do completions
      @config.traverse do |node|
        self.add_terms(node.keys)
        node.values.each do |v|
          if v.is_a? String
            self.add_terms(v)
          end
        end
      end

      @config.each_path do |path|
        self.add_terms(path.join("."))
      end
    end

    # Add the supplied list of terms to the tab completions dict.
    # Will not add terms containing less than 3 characters.  Helpfully
    # adds the individual components of input strings containing "."s,
    # on the assumption that they are indexes into the config data
    # structure.
    def add_terms(*terms)
      terms.flatten.each do |term|
        raise ArgumentError unless term.is_a? String
        if term.size > 2 && term !~ /\s/
          @completions << term
          # WARNING: thar be recursion
          self.add_terms(term.split(".")) if term =~ /\./
        end
      end
    end

    # Show the requested configuration element, which is the whole
    # data structure in the case you don't specify an index.
    def show(index=nil)
      if index
        if val = @config.find(index.split("."))
          self.display(val)
          self.add_terms(index)
        else
          puts "null"
        end
      else
        self.display(@config)
      end
    end

    # Output a value as JSON.
    def display (val)
      case val
      when Hash, Array
        puts JSON.pretty_generate(val)
      else
        # TODO: look for cases where #pp output isn't
        # the same as JSON vals.
        pp val
      end
    end

    def set(key, val)
      bits = key.split(".")
      @config.create_path(bits) do |h,k|
        begin
          h[k] = val
          self.add_terms(key, val)
        rescue => e
          puts "Can't set #{key}: a value already exists"
          pp h
        end
      end
    end

    # Write the current configuration and completions dict to file.
    def save
      File.open(@base_file, "w") do |f|
        f.puts(JSON.pretty_generate(@config))
      end
      File.open(@completions_file, "w") do |f|
        f.puts(JSON.pretty_generate(@completions.to_a))
      end
    end

    # Takes a result object, prepends the current configuration,
    # generates pretty JSON from the above, then writes it to a
    # results file numbered sequentially.
    def store(result)
      file = "#{@dir}/#{self.current_number}.json"
      File.open(file, "w") do |f|
        f.puts(JSON.pretty_generate([@config, result]))
      end
      puts "Stored results in #{file}"
      puts
    end

    # Determines the current result number by inspecting the storage
    # directory's previously written result files.
    def current_number
      files = Dir["#{@dir}/*.json"].map {|f| f.slice(/\d+/) }.compact
      "%04d" % (files.last.to_i + 1)
    end

  end
end

