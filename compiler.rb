require 'pry'
require_relative 'tokenizer'
require_relative 'syntax_analyzer'
#require_relative 'xml_writer'
require_relative 'vm_writer'
require 'optparse'
require 'nokogiri'
options = {}

o = OptionParser.new do |opts|
  OptionParser::Version = [1, 0, 0]
  opts.banner = 'Usage: compiler.rb jackfile1, jackfile2.. [options]' + "\n" + '       compiler.rb jack-directory [options]'

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  # No argument, shows at tail.  This will print an options summary.
  # Try it and see!
  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end

  # Another typical switch to print the version.
  opts.on_tail('--version', 'Show version') do
    puts OptionParser::Version.join('.')
    exit
  end
end

begin
  o.parse! ARGV
rescue OptionParser::InvalidOption => e
  puts e
  puts o
  exit 1
end

if ARGV.empty?
  puts 'No jackfile!'
  puts o
  exit(1)
end

jack_files = []
if ARGV.size == 1 && File.directory?(File.expand_path(ARGV[0]))
  Dir[File.expand_path("#{ARGV[0]}/*.jack")].each do |f|
    jack_files << File.expand_path(f)
  end
else
  jack_files = ARGV.select { |f| f.end_with? '.jack' }.map { |f| File.expand_path(f) }
end

$symbol_table_stack = []
jack_files.each do |jack_file|
  File.open(jack_file, 'r') do |file|
    tokenizer = Tokenizer.new file
    jack_class = JackClass.new(Context.new(tokenizer.each))
    $symbol_table_stack.push jack_class
    jack_class.parse
    #xml_file = File.new(jack_file.sub(/jack$/, 'xmla'), 'w')
    #doc = Nokogiri::XML(jack_class.to_xml, &:noblanks)
    #xml_file.puts doc.to_xml(indent: 2)
    #xml_file.puts jack_class.to_xml
    #xml_file.close
    vm_file = File.new(jack_file.sub(/jack$/, 'vm'), 'w')

    VMWriter.define_method :vm_file do
      vm_file
    end
    jack_class.vm_file
    jack_class.write_vm_code
    jack_class.vm_file.close
    $symbol_table_stack.pop
  end
end
