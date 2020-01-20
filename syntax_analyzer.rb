# frozen_string_literal: true

require_relative 'tokenizer'
require_relative 'hack'
# provides convention function for syntax parsing
module ASTNode
  def initialize(token_enumerator)
    @source = token_enumerator
  end

  def expect_keyword(name_expr)
    token = @source.next
    raise "A keyword #{name_expr} is expected but #{token.text} is given in #{token.line_number}" unless token.text =~ /#{name_expr}/

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise "#{name_expr} not found, program is malformed!"
  end

  def keyword?(name_expr)
    token = @source.peek
    token.text =~ /#{name_expr}/
  rescue StopIteration
    raise "#{name_expr} not found, program is malformed!"
  end

  def expect_identifier
    token = @source.next
    raise "An identifier is expected but one #{token.class} #{token.text} is given in #{token.line_number}" unless token.identifier?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'An identifier is expected, program is malformed!'
  end

  def expect_string
    token = @source.next
    raise "A string is expected but one #{token.class} #{token.text} is given in #{token.line_number}" unless token.string_constant?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'A string is expected, program is malformed!'
  end

  def expect_integer
    token = @source.next
    raise "An integer is expected but one #{token.class} #{token.text} is given in #{token.line_number}" unless token.integer_constant?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'An integer is expected, program is malformed!'
  end

  def expect_mark(name)
    token = @source.next
    raise "A mark #{name} is expected but #{token.text} is given in #{token.line_number}" unless token.text == name
  rescue StopIteration
    raise "#{name} not found, program is malformed!"
  end

  def mark?(name)
    token = @source.peek
    token.text == name
  rescue StopIteration
    raise "#{name} not found, program is malformed!"
  end

  def expect_var_type
    token = @source.next
    unless token.identifier? || token.text =~ /int|char|boolean/
      raise "A class name or type(int, char or boolean) is expected but one #{token.class} #{token.text} is given in #{token.line_number}"
    end

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def var_type?
    token = @source.peek
    token.identifier? || token.text =~ /int|char|boolean/
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def expect_return_type
    token = @source.next
    unless token.identifier? || token.text =~ /int|char|boolean|void/
      raise "A class name or type(int, char, boolean or void) is expected but one #{token.class} #{token.text} is given in #{token.line_number}"
    end

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def return_type?
    token = @source.peek
    token.identifier? || token.text =~ /int|char|boolean|void/
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end
end

# presents a class of Jack language
class JackClass
  include ASTNode
  attr_reader :class_name

  def expect_class_var_dec
    class_var_dec = ClassVarDec.new @source
    class_var_dec.parse
  end

  def expect_subroutine_dec
    subroutine_dec = SubroutineDec.new @source
    subroutine_dec.parse
  end

  def parse
    expect_keyword 'class'
    expect_identifier { |id| @class_name = id }
    expect_mark '{'
    while (class_var_dec = expect_class_var_dec)
      @children << class_var_dec
    end
    while (subroutine_dec = expect_subroutine_dec)
      @children << subroutine_dec
    end
    expect_mark '}'
    self
  end
end

# presents a class field definition
class ClassVarDec
  include ASTNode
  attr_reader :type, :kind

  def var_list
    @var_list ||= []
  end

  def parse
    return nil unless keyword? 'static|field'

    expect_keyword ('static|field') { |kind| @kind = kind }
    expect_var_type { |type| @type = type }
    expect_identifier { |id| var_list << id }
    while mark? ','
      expect_mark ','
      expect_identifier { |id| var_list << id }
    end
    expect_mark ';'
    self
  end
end

class SubroutineDec
  include ASTNode
  attr_reader :kind, :return_type, :subroutine_name, :parameter_list, :body

  def expect_parameter_list
    plist = ParameterList.new @source
    plist.parse
  end

  def expect_subroutine_body; end

  def parse
    return nil unless keyword? 'constructor|function|method'

    expect_keyword ('constructor|function|method') { |kind| @kind = kind }
    expect_return_type { |type| @return_type = type }
    expect_identifier { |id| @subroutine_name = id }
    expect_mark '('
    @subroutine_name = expect_parameter_list
    expect_mark ')'
    @body = expect_subroutine_body
  end
end

class SubroutineBody
  include ASTNode

  def var_dec_list
    @var_dec_list ||= []
  end

  def statements
    @statements ||= []
  end

  def expect_var_dec
    var_dec = VarDec.new @source
    var_dec.parse
  end

  def expect_statement
    statement_type = expect_keyword 'let|if|while|do|return'
    ruby_class_name = "#{statement_type.capitalize}Statement"
    ruby_class = Object.const_get(ruby_class_name)
    statement_obj = ruby_class.new @source
    statement_obj.parse
  end

  def parse
    expect_mark '{'
    while (var_dec = expect_var_dec)
      var_dec_list << var_dec
    end

    while (statement = expect_statement)
      statements << statement
    end

    expect_mark '}'
    self
  end
end

class Statement
  include ASTNode

  def expect_expression(mark = nil, &end_predicate)
    expression = Expression.new @source
    expression.parse(mark, &end_predicate)
  end
end

class LetStatement < Statement
  attr_reader :assign_expression

  def parse
    @assign_expression = expect_expression { |token| token.text == ';' }
    raise 'No = found, expect an assign expression' unless @assign_expression.operator == Operator::EQ

    self
  end
end

class ConditionStatement < Statement
  attr_reader :condition_expression

  def statements
    @statements ||= []
  end

  def parse
    @condition_expression = expect_expression('()')
    expect_mark '{'
    while (statement = expect_statement)
      statements << statement
    end
    expect_mark '}'
    self
  end
end

class IfStatement < ConditionStatement
  def else_statements
    @else_statements ||= []
  end

  def parse
    super
    return self unless keyword? 'else'

    expect_keyword 'else'
    expect_mark '{'
    while (statement = expect_statement)
      else_statements << statement
    end
    expect_mark '}'
    self
  end
end

class WhileStatement < ConditionStatement
end

class DoStatement < Statement
  attr_reader :subroutine_call

  def parse
    subroutine_name = expect_identifier
    if mark? '.'
      expect_mark '.'
      object_name = subroutine_name
      subroutine_name = expect_identifier
    end
    @subroutine_call = SubroutineCall.new(subroutine_name, ExpressionList.new(@source).parse, object_name)
    expect_mark ';'
    self
  end
end

class ReturnStatement < Statement
  attr_reader :return_expression

  def parse
    e = Expression.new @source
    @return_expresstion = e.parse { |token| token.text == ';' }
    expect_mark ';'
    self
  end
end

class Operator
  attr_reader :op, :n, :p

  def initialize(op, n, p)
    @op = op
    @n = n
    @p = p
  end

  LEFT_PARENTHESIS = Operator.new('(', -1, 1)
  RIGHT_PARENTHESIS = Operator.new(')', -1, 1)
  NOT = Operator.new('~', 1, 0)
  NEG = Operator.new('-', 1, 0)
  PRODUCT = Operator.new('*', 2, -1)
  DIVIDE = Operator.new('/', 2, -1)
  PLUS = Operator.new('+', 2, -2)
  MINUS = Operator.new('-', 2, -2)
  AND = Operator.new('&', 2, -3)
  OR = Operator.new('|', 2, -4)
  GT = Operator.new('>', 2, -4)
  LT = Operator.new('<', 2, -4)
  EQ = Operator.new('=', 2, -4)
  class << self
    def get_operator(op, last_element = :operand)
      case op
      when '~'
        NOT
      when '-'
        return MINUS if last_element == :operand

        NEG
      when '*'
        PRODUCT
      when '/'
        DIVIDE
      when '+'
        PLUS
      when '&'
        AND
      when '|'
        OR
      when '>'
        GT
      when '<'
        LT
      when '='
        EQ
      end
    end
  end
end

class Term
end

class SimpleTerm < Term
  attr_reader :value

  def initialize(value)
    @value = value
  end
end

class ExpressionList
  include ASTNode

  def expressions
    @expressions ||= []
  end

  def parse
    until yield @source.peek
      e = Expression.new @source
      expressions << e.parse { |token| token.text == ',' }
      expect_mark ','
    end
  end
end

class Expression < Term
  include ASTNode
  attr_accessor :operator, :operands

  def initialize(token_enumerator = nil)
    super token_enumerator
  end

  class << self
    def create(operator, operands)
      e = Expression.new
      e.operator = operator
      e.operands = operands
    end
  end

  def end?(mark)
    nested_mark = 0
    lambda { |token|
      if token.text == mark[0]
        nested_mark += 1
      elsif token.text == mark[1]
        nested_mark -= 1
      end
      nested_mark.zero?
    }
  end

  private

  def push_operand(x)
    @operand_stack ||= []
    @operand_stack.push(x)
    @last_element = :operand
  end

  def pop_operand(n = 1)
    @operand_stack.pop n
  end

  def push_operator(x)
    @operator_stack ||= []
    @operand_stack.push(x)
    @last_element = :operator
  end

  def pop_operator(n = 1)
    @operator_stack.pop n
  end

  public

  def parse(mark = nil)
    @last_element = :initial
    until block_given? ? (yield @source.peek) : end?(mark).call
      token = @source.next
      # process operand
      begin
        # keyword value
        next push_operand(KeywordConstant.new(token.text)) if token.text =~ /true|false|null|this/
        # integer value
        next push_operand(IntegerConstant.new(token.text)) if token.integer_constant?
        # string value
        next push_operand(StringConstant.new(token.text)) if token.string_constant?

        if token.identifier?
          # array element
          next push_operand(ArrayElement.new(token.text, Expression.new(@source).parse('[]'))) if @source.peek.text == '['
          # subroutine call
          next push_operand(SubroutineCall.new(token.text, ExpressionList.new(@source).parse)) if @source.peek.text == '('

          # object method call
          if @source.peek.text == '.'
            subroutine_name = token.text
            expect_mark '.'
            object_name = expect_identifier
            raise "A pair of () are required after #{object_name}.#{subroutine_name}" unless mark? '('

            next push_operand(SubroutineCall.new(subroutine_name, ExpressionList.new(@source).parse, object_name))
          end
          # variable
          next next push_operand(VariableReference.new(token.text))
        end
      end
      # process operator
      begin
        case token.text
        when '('
          push_operator Operator::LEFT_PARENTHESIS
        when ')'
          until @operator_stack.last == Operator::LEFT_PARENTHESIS
            operator = pop_operator
            push_operand Expression.create(operator, pop_operand(operator.n))
          end
          pop_operator # pop ')'
        else
          if @operator_stack.empty? || @operator_stack.last == Operator::LEFT_PARENTHESIS
            next push_operator Operator.get_operator(token.text, @last_element)
          end

          until @operator_stack.empty? || Operator.get_operator(token.text, @last_element).p > @operator_stack.last.p
            operator = pop_operator
            push_operand Expression.create(operator, pop_operand(operator.n))
          end
          push_operator Operator.get_operator(token.text, @last_element)
        end
      end
    end
    until @operator_stack.empty
      operator = pop_operator
      push_operand Expression.create(operator, pop_operand(operator.n))
    end
    @operand_stack.last
  end
end

class IntegerConstant < SimpleTerm
end

class StringConstant < SimpleTerm
end

class KeywordConstant < SimpleTerm
end

class VariableReference < SimpleTerm
end

class ArrayElement < Term
  attr_reader :var_name, :index_expression

  def initialize(var_name, index_expression)
    @var_name = var_name
    @index_expression = index_expression
  end
end

class SubroutineCall < Term
  attr_reader :object, :subroutine_name, :expression_list

  def initialize(subroutine_name, expression_list, object = nil)
    @object = object
    @subroutine_name = subroutine_name
    @expression_list = expression_list
  end
end

class VarDec < ParameterList
  def parse
    return nil if keyword? 'var'

    values << VariableDef.new(expect_var_type, expect_identifier)
    while mark? ','
      expect_mark ','
      values << VariableDef.new(expect_var_type, expect_identifier)
    end
    expect_mark ';'
    self
  end
end

class ParameterList
  include ASTNode
  include Enumerable

  def values
    @values ||= []
  end

  def each
    values.each unless block_given?
    values.each do |p|
      yield p
    end
  end

  def parse
    values << VariableDef.new(expect_var_type, expect_identifier) if var_type?
    while mark? ','
      expect_mark ','
      values << VariableDef.new(expect_var_type, expect_identifier)
    end
    self
  end
end

class VariableDef
  attr_reader :type, :name

  def initialize(type, name)
    @type = type
    @name = name
  end
end

class SyntaxAnalyzer
  def initialize(tokenizer)
    @source = tokenizer.each
  end

  def parse
    JackClass.new @source
  end
end
