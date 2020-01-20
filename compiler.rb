require_relative 'tokenizer'
file = File.new('Main.jack', 'r')
tokenizer = Tokenizer.new file
token_enum = tokenizer.each

file.close
