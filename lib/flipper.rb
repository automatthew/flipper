# stdlib
require "pp"
require "set"
require "open3"
require "fileutils"

# others
require "rubygems"
gem "rb-readline"
require "readline"
Readline.completion_append_character = nil
#Readline.basic_word_break_characters = ""

gem "json"
require "json"

# ours
require "hash_tree"
require "flipper/store"

class Flipper

  attr_reader :store, :commands
  def initialize(dir)
    @store = Flipper::Store.new(dir)
    @patterns = {}
    @commands = Set.new
    @state = :rest
    Readline.completion_proc = self.method(:complete)
  end

  def complete(str)
    case Readline.line_buffer
    when /^\s*!/
      # if we're in the middle of a bang-exec command, completion
      # should look at the file system.
      self.dir_complete(str)
    else
      # otherwise use the internal dict.
      self.term_complete(str)
    end
  end

  def dir_complete(str)
    Dir.glob("#{str}*")
  end

  def term_complete(str)
    # Terms can be either commands or indexes into the configuration
    # data structure.  No command contains a ".", so that's the test
    # we use to distinguish.
    bits = str.split(".")
    if bits.size > 1
      # Somebody should have documented this when he wrote it, because
      # he now does not remember exactly what he was trying to achieve.
      # He thinks that it's an attempt to allow completion of either
      # full configuration index strings, or of component parts.
      # E.g., if the configuration contains foo.bar.baz, this code
      # will offer both "foo" and "foo.bar.baz" as completions for "fo".
      v1 = @store.completions.grep(/^#{Regexp.escape(str)}/)
      v2 = @store.completions.grep(/^#{Regexp.escape(bits.last)}/)
      (v1 + v2.map {|x| (bits.slice(0..-2) << x).join(".") }).uniq
    else
      self.command_complete(str) +
        @store.completions.grep(/^#{Regexp.escape(str)}/)
    end
  end

  def command_complete(str)
    @commands.grep(/^#{Regexp.escape(str)}/) 
  end

  def sanitize(str)
    # ANSI code stripper regex cargo culted from
    # http://www.commandlinefu.com/commands/view/3584/remove-color-codes-special-characters-with-sed
    str.gsub(/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]/, "")
  end

  # Execute the given shell command, optionally storing the resulting stdout
  # and stderr data along with a "config-stamp".
  def fire(command)
    @store.set(%w[tester command], command)

    stdout, stderr = [], []
    cmd = Open3.popen3(command) do |i, o, e|
      i.close
      t0 = Thread.new do
        o.each_line do |line|
          stdout << self.sanitize(line)
          $stdout.puts "  " << line
        end
      end
      t1 = Thread.new do
        e.each_line do |line|
          stderr << self.sanitize(line)
          $stderr.puts "  " << line
        end
      end
      t0.join
      t1.join
    end

    print "\nStore results? (y/N)"
    if Readline.readline(" ", true) == "y"
      # save config to _base.json
      @store.save
      puts "Saved current config"
      # create a new numbered file, saving in it the current
      # config and the results of the command
      @store.store(:timestamp => Time.now.to_i, :stdout => stdout.join, :stderr => stderr.join)
    end
  end
  
  # Execute the given shell command, with no option to store the results.
  def exec(command)
    cmd = Open3.popen3(command) do |i, o, e|
      i.close
      t0 = Thread.new do
        o.each_line do |line|
          $stdout.puts "  " << line
        end
      end
      t1 = Thread.new do
        e.each_line do |line|
          $stderr.puts "  " << line
        end
      end
      t0.join
      t1.join
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

  # Attempt to find a registered command that matches the input
  # string.  Upon failure, print an encouraging message.
  def parse(input_string)
    _p, block= @patterns.detect do |pattern, block|
      pattern === input_string
    end
    if block
      # Perlish global ugliness necessitated by the use of
      # Enumerable#detect above.  FIXME.
      if $1
        # if the regex had a group (based on the assumption that $1
        # represents the result of the === that matched), call the block
        # with all the group matches as arguments.
        block.call($~[1..-1])
      else
        block.call()
      end
    else
      puts "i love you"
    end
  end

end

