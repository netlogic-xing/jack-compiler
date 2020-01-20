# base module
class Regexp
  def |(re)
    Regexp.union(self, re)
  end
end
module Hack
  # enhance Regexp

  class << self
    def create_element(text, line_number)
      case text
      when /(?<keyword>class|constructor|function|method|field|static|var
                          |int|char|boolean|void|true|false|null|this|let|do
                          |if|else|while|return)/x
        Keyword.new text, line_number
      when /(?<mark>[\{\}\(\)\[\]\.,;\+\-\*\/&\|\<\>=~])/
        Mark.new text, line_number
      when /(?<integer>\d{1,5})/
        IntegerConstant.new text, line_number
      when /(?<string>"\.*")/
        StringConstant.new text, line_number
      when /(?<identifier>[a-zA-Z_][\d\w_]*)/
        Identifier.new text, line_number
      else
        raise "Unrecognized token #{text}"
      end
    end
  end

  class Element
    class << self
      def one_line_element
        /((?<mark>[\{\}\(\)\[\]\.,;\+\-\*\/&\|\<\>=~])|\w+)/
      end
    end
    attr_accessor :text, :line_number

    def to_s
      "#{@text} @ #{@line_number}"
    end

    %w[Keyword Mark IntegerConstant StringConstant Identifier].each do |name|
      method_name_main = name.sub(/([a-z])([A-Z])/) { "#{$1}_#{$2.downcase}" }.downcase
      define_method("#{method_name_main}?") do
        return self.class.name == name
      end
    end

    def initialize(text, line_number)
      @text = text
      @line_number = line_number
    end
  end

  class Keyword < Element
    class << self
      def pattern
        /(?<keyword>class|constructor|function|method|field|static|var
          |int|char|boolean|void|true|false|null|this|let|do
          |if|else|while|return)/x
      end
    end
  end

  class Mark < Element
    class << self
      def pattern
        /(?<mark>[\{\}\(\)\[\]\.,;\+\-\*\/&\|\<\>=~])/
      end
    end
  end

  class IntegerConstant < Element
    class << self
      def pattern
        /(?<integer>\d{1,5})/
      end
    end
  end

  class StringConstant < Element
    class << self
      def pattern
        /(?<string_in_line>".*")/m
      end
    end
  end

  class Identifier < Element
    class << self
      def pattern
        /(?<identifier>[a-zA-Z_][\d\w_]*)/
      end
    end
  end
end
