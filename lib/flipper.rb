# stdlib
require "pp"
require "set"
require "readline"
require "open3"
require "fileutils"

# others
require "rubygems"
require "json"

# ours
$Here = File.expand_path(File.dirname(__FILE__))
load "#{$Here}/hash_tree.rb"


class FlipperStore

  attr_reader :completions
  def initialize(directory)
    @dir = File.expand_path(directory)
    FileUtils.mkdir_p(@dir)
    @base_file = "#{directory}/_base.json"
    @completions_file = "#{directory}/_comp.json"
    self.load
  end

  def method_missing(name, *args)
    @config.respond_to?(name) ? @config.send(name, *args) : super
  end

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

  def add_terms(*terms)
    terms.flatten.each do |term|
      raise ArgumentError unless term.is_a? String
      if term.size > 2 && term !~ /\s/
        @completions << term
        self.add_terms(term.split(".")) if term =~ /\./
      end
    end
  end

  def show(arg=nil)
    if arg
      if val = @config.find(arg.split("."))
        self.display(val)
        self.add_terms(arg)
      else
        puts "null"
      end
    else
      self.display(@config)
    end
  end

  def display (val)
    case val
    when Hash, Array
      puts JSON.pretty_generate(val)
    else
      pp val
    end
  end

  def lineproc(line)
    key, val = line.chomp.split(/\s*=\s*/)
    if key
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
  end

  def save
    File.open(@base_file, "w") do |f|
      f.puts(JSON.pretty_generate(@config))
    end
    File.open(@completions_file, "w") do |f|
      f.puts(JSON.pretty_generate(@completions.to_a))
    end
  end

  def store(result)
    file = "#{@dir}/#{self.current_number}.json"
    File.open(file, "w") do |f|
      f.puts(JSON.pretty_generate([@config, result]))
    end
    puts "Stored results in #{file}"
  end

  def current_number
    files = Dir["#{@dir}/*.json"].map {|f| f.slice(/\d+/) }.compact
    "%04d" % (files.last.to_i + 1)
  end

end

class Flipper

  attr_reader :store, :commands
  def initialize(dir)
    @store = FlipperStore.new(dir)
    @patterns = {}
    @commands = Set.new
  end

  def completion_proc
    @cproc ||= lambda do |str|
      bits = str.split(".")
      if bits.size > 1
        v1 = @store.completions.grep(/^#{Regexp.escape(str)}/)
        v2 = @store.completions.grep(/^#{Regexp.escape(bits.last)}/)
        (v1 + v2.map {|x| (bits.slice(0..-2) << x).join(".") }).uniq
      else
        @commands.grep(/^#{Regexp.escape(str)}/) + 
        @store.completions.grep(/^#{Regexp.escape(str)}/)
      end
    end
  end

  def sanitize(str)
    # ANSI code stripper regex cargo culted from
    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    str.gsub(/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]/, "")
  end

  def fire(command)
    @store.set(%w[tester command], command)

    stdout, stderr = [], []
    cmd = Open3.popen3(command) do |i, o, e|
      i.close
      t0 = Thread.new do
        o.each_line do |line|
          stdout << self.sanitize(line)
          $stdout.puts line
        end
      end
      t1 = Thread.new do
        e.each_line do |line|
          stderr << self.sanitize(line)
          $stderr.puts line
        end
      end
      t0.join
      t1.join
    end

    print "Store results? (y/N)"
    if Readline.readline(" ", true) == "y"
      # save config to _base.json
      @store.save
      # create a new numbered file, saving in it the current
      # config and the results of the command
      @store.store(:stdout => stdout.join, :stderr => stderr.join)
    end
  end
  

  def on(*pattern, &block)
    pattern.flatten.each do |pattern|
      @patterns[pattern] = block
      self.add_command(pattern)
    end
  end

  def add_command(pattern)
    if pattern.is_a?(String)
      @commands << pattern
    else
      bits = pattern.source.split(" ")
      if bits.size > 1
        @commands << bits.first
      end
    end
  end

  def parse(entry)
    _p, block= @patterns.detect do |pattern, block|
      pattern === entry
    end
    if block
      arg = $1 ? $~[1..-1] : entry
      #self.instance_exec(block, arg)
      block.call(arg)
    else
      puts "i love you"
    end
  end

end

