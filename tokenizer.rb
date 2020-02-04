require_relative 'hack'
require 'strscan'

# lexical
class Tokenizer
  include Enumerable

  def initialize(file)
    @file = file
  end

  def each
    return to_enum unless block_given?

    scanner = StringScanner.new('')
    mode = :NORMAL # mode = one of :NOMRAL, :STRING, :COMMENT
    string_begin = 0
    comment_begin = 0
    @file.each_line do |line|
      scanner << line
      until scanner.eos?
        case mode
        when :NORMAL
          break if scanner.skip(/\s*\/\/.*\n/) # skip single line comment
          break if scanner.skip(/\s+\n/) # skip blank line
          next if scanner.skip(/\s+/) # skip the blank character
          next if scanner.skip(/\/\*.*\*\//) # skip comment in line

          if scanner.check(/\/\*/) # start a comment across lines
            mode = :COMMENT
            comment_begin = @file.lineno
            break # skip until comment end
          end

          if (token = scanner.scan(Hack::Element.one_line_element))
            yield Hack.create_element token, @file.lineno
            next
          end

          if (token = scanner.scan(Hack::StringConstant.pattern))
            yield Hack::StringConstant.new token, @file.lineno
            next
          end

          if scanner.check(/"/)
            mode = :STRING
            string_begin = @file.lineno
            break # skip until String end
          end

        when :STRING
          if (token = scanner.scan(Hack::StringConstant.pattern))
            yield Hack::StringConstant token, @file.lineno
            mode = :NORMAL
            next
          end

          break # String isn't end yet
        when :COMMENT
          if scanner.skip(/\/\*.*\*\//m)
            mode = :NORMAL
            next
          end

          break # comment isn't end yet
        end
      end
    end

    raise "A string started from #{string_begin} expects an end flag(\")" if mode == :STRING
    raise "A comment started from #{comment_begin} expects an end flag(*/)" if mode == :COMMENT
  end
end