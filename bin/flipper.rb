#!/usr/bin/env ruby

here = File.expand_path(File.dirname(__FILE__))
require "#{here}/../lib/flipper"

flipper = Flipper.new("#{Dir.pwd}/flipper")

flipper.instance_eval do
  on("help") do
    commands = flipper.commands.select {|c| c.size > 1 } + ["!"]
    puts "* Available commands: " << commands.sort.join(" ")
    puts "* Set values with:  foo.bar = whitespace is ok"
    puts "* Tab completion works for commands and config keys"
  end

  on("") do
    puts "Giving me the silent treatment, eh?"
  end

  on("quit", "q") do
    exit
  end

  on("save") { flipper.store.save }

  on("reload") { flipper.store.load }

  on(/^\!\s*(.*)$/) do |args|
    flipper.exec(args.first)
  end

  on(/run\s+(.*)$/) do |args|
    flipper.fire(args.first)
  end

  on("show", "s") do
    flipper.store.show
  end

  on(/delete (.+)$/) do |args|
    args.each do |arg|
      pp flipper.store.remove(*arg.split("."))
    end
  end

  on(/^([^!\s]+?)\s+=\s+(.+)$/) do |args|
    flipper.store.set2(args[0], args[1])
    #flipper.store.lineproc(arg)
  end

  on(/show (\S+)$/) do |args|
    args.each { |arg| flipper.store.show(arg) }
  end

  on("run") do
    if command = flipper.store.find(["tester", "command"])
      puts command
      flipper.fire(command)
    else
      puts "how can I run I have no legs?"
      puts "(set tester.command or use !)"
      exit
    end
  end
end


Readline.completion_proc = flipper.method(:complete)
#Readline.basic_word_break_characters = ""

if ARGV.size > 0
  flipper.fire(ARGV.join(" "))
end
while line = Readline.readline("<3: ", true)
  flipper.parse(line.chomp)
end
