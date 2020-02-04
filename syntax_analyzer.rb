# frozen_string_literal: true

require_relative 'tokenizer'
require_relative 'hack'
require_relative 'symbol_table'
class Context
  attr_accessor :source, :vm_file

  def initialize(source)
    @context = source
  end

  def next
    @context.next
  end

  def peek
    @context.peek
  end
end

class ASTNodeBase

end
# provides convention function for syntax parsing
class ASTNode < ASTNodeBase
  attr_reader :line

  def initialize(context)
    @context = context
    @line = context&.peek&.line_number
  end

  def end?(mark)
    nested_mark = 1
    ended = false
    lambda { |token|
      return true if ended

      if token.text == mark[0]
        nested_mark += 1
      elsif token.text == mark[1]
        nested_mark -= 1
      end
      ended = nested_mark.zero?
    }
  end

  def expect_keyword(name_expr)
    token = @context.next
    raise "A keyword #{name_expr} is expected but #{token.text} is given in line: #{token.line_number}" unless token.text =~ /#{name_expr}/

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise "#{name_expr} not found, program is malformed!"
  end

  def keyword?(name_expr)
    token = @context.peek
    token.text =~ /#{name_expr}/
  rescue StopIteration
    raise "#{name_expr} not found, program is malformed!"
  end

  def expect_identifier
    token = @context.next
    raise "An identifier is expected but one #{token.class} #{token.text} is given in line: #{token.line_number}" unless token.identifier?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'An identifier is expected, program is malformed!'
  end

  def expect_string
    token = @context.next
    raise "A string is expected but one #{token.class} #{token.text} is given in line: #{token.line_number}" unless token.string_constant?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'A string is expected, program is malformed!'
  end

  def expect_integer
    token = @context.next
    raise "An integer is expected but one #{token.class} #{token.text} is given in line: #{token.line_number}" unless token.integer_constant?

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'An integer is expected, program is malformed!'
  end

  def expect_mark(name)
    token = @context.next
    raise "A mark #{name} is expected but #{token.text} is given in line: #{token.line_number}" unless token.text == name
  rescue StopIteration
    raise "#{name} not found, program is malformed!"
  end

  def mark?(name)
    token = @context.peek
    token.text == name
  rescue StopIteration
    raise "#{name} not found, program is malformed!"
  end

  def expect_var_type
    token = @context.next
    unless token.identifier? || token.text =~ /int|char|boolean/
      raise "A class name or type(int, char or boolean) is expected but one #{token.class} #{token.text} is given in line: #{token.line_number}"
    end

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def var_type?
    token = @context.peek
    token.identifier? || token.text =~ /int|char|boolean/
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def expect_return_type
    token = @context.next
    unless token.identifier? || token.text =~ /int|char|boolean|void/
      raise "A class name or type(int, char, boolean or void) is expected but one #{token.class} #{token.text} is given in line: #{token.line_number}"
    end

    yield(token.text) if block_given?
    token.text
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def return_type?
    token = @context.peek
    token.identifier? || token.text =~ /int|char|boolean|void/
  rescue StopIteration
    raise 'class name or type not found, program is malformed!'
  end

  def expect_statement
    return nil unless keyword? 'let|if|while|do|return'

    statement_type = expect_keyword 'let|if|while|do|return'
    ruby_class_name = "#{statement_type.capitalize}Statement"
    ruby_class = Object.const_get(ruby_class_name)
    statement_obj = ruby_class.new @context
    statement_obj.parse
  end
end

# presents a class of Jack language
class JackClass < ASTNode
  include SymbolTable
  attr_reader :class_name

  def class_var_decs
    @class_var_decs ||= []
  end

  def subroutine_decs
    @subroutine_decs ||= []
  end

  def expect_class_var_dec
    class_var_dec = ClassVarDec.new @context
    return nil unless class_var_dec.parse

    class_var_dec.var_list.each do |var|
      define(var, class_var_dec.kind, class_var_dec.type)
    end
    class_var_dec
  end

  def expect_subroutine_dec
    subroutine_dec = SubroutineDec.new @context
    $symbol_table_stack.push subroutine_dec
    subroutine_dec = subroutine_dec.parse
    $symbol_table_stack.pop
    subroutine_dec.parent = self if subroutine_dec
    subroutine_dec
  end

  def parse
    expect_keyword 'class'
    expect_identifier do |id|
      @class_name = id.to_sym
      @table_name = class_name
    end
    expect_mark '{'
    while (class_var_dec = expect_class_var_dec)
      class_var_decs << class_var_dec
    end
    while (subroutine_dec = expect_subroutine_dec)
      subroutine_decs << subroutine_dec
    end
    expect_mark '}'
    self
  end
end

# presents a class field definition
class ClassVarDec < ASTNode
  attr_reader :type, :kind

  def var_list
    @var_list ||= []
  end

  def parse
    return nil unless keyword? 'static|field'

    expect_keyword ('static|field') { |kind| @kind = kind.to_sym }
    expect_var_type { |type| @type = type.to_sym }
    expect_identifier { |id| var_list << id.to_sym }
    while mark? ','
      expect_mark ','
      expect_identifier { |id| var_list << id.to_sym }
    end
    expect_mark ';'
    self
  end
end

class SubroutineDec < ASTNode
  include SymbolTable
  attr_reader :kind, :return_type, :subroutine_name, :parameter_list, :body

  def expect_parameter_list
    plist = ParameterList.new @context
    plist.parse
  end

  def expect_subroutine_body
    body = SubroutineBody.new @context
    body.parse
  end

  def parse
    return nil unless keyword? 'constructor|function|method'

    expect_keyword ('constructor|function|method') { |kind| @kind = kind.to_sym }
    expect_return_type { |type| @return_type = type.to_sym }
    expect_identifier do |id|
      @subroutine_name = id.to_sym
      @table_name = subroutine_name
    end
    expect_mark '('
    @parameter_list = expect_parameter_list
    parameter_list.each do |variable_def|
      define(variable_def.name, :argument, variable_def.type)
    end
    expect_mark ')'
    @body = expect_subroutine_body
    @body.var_dec_list.each do |var_def|
      var_def.name_list.each { |name| define(name, :local, var_def.type) }
    end
    self
  end
end

class SubroutineBody < ASTNode

  def var_dec_list
    @var_dec_list ||= []
  end

  def statements
    @statements ||= []
  end

  def expect_var_dec
    var_dec = VarDec.new @context
    var_dec.parse
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

class Statement < ASTNode

  def expect_expression(mark = nil, &end_predicate)
    expression = Expression.new @context
    expression.parse(mark, &end_predicate)
  end
end

class LetStatement < Statement
  attr_reader :var_name, :index_expression, :value_expression

  def parse
    @var_name = expect_identifier
    if mark? '['
      expect_mark '['
      @index_expression = expect_expression('[]')
      expect_mark ']'
    end
    expect_mark '='
    @value_expression = expect_expression { |token| token.text == ';' }
    expect_mark ';'
    self
  end
end

class ConditionStatement < Statement
  attr_reader :condition_expression

  def statements
    @statements ||= []
  end

  def parse
    expect_mark '('
    @condition_expression = expect_expression('()')
    expect_mark ')'
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
    expect_mark '('
    @subroutine_call = SubroutineCall.new(subroutine_name, ExpressionList.new(@context).parse, object_name)
    expect_mark ')'
    expect_mark ';'
    self
  end
end

class ReturnStatement < Statement
  attr_reader :return_expression

  def parse
    e = Expression.new @context
    @return_expression = e.parse { |token| token.text == ';' }
    expect_mark ';'
    self
  end
end

class Operator < ASTNodeBase
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

module Term

end

class SimpleTerm < ASTNodeBase
  include Term
  attr_reader :value

  def initialize(value)
    @value = value
  end
end

class ExpressionList < ASTNode

  def expressions
    @expressions ||= []
  end

  def parse
    end_predicate = end?('()')
    ended = false
    until ended
      e = Expression.new @context
      e = e.parse do |token|
        token.text == ',' || (ended = end_predicate.call(token))
      end
      expressions << e if e
      expect_mark ',' if mark? ','
    end
    self
  end
end

class Expression < ASTNode
  include Term
  attr_accessor :operator, :operands

  def initialize(context = nil)
    super context
    @operator_stack = []
    @operand_stack = []
  end

  class << self
    def create(operator, operands)
      e = Expression.new @context
      e.operator = operator
      e.operands = if operands.instance_of? Array
                     operands
                   else
                     [operands]
                   end
      e
    end
  end

  private

  def push_operand(x)
    @operand_stack.push(x)
    @last_element = :operand
  end

  def pop_operand(n = 1)
    return @operand_stack.pop if n == 1

    @operand_stack.pop n
  end

  def push_operator(x)
    @operator_stack.push(x)
    @last_element = :operator
  end

  def pop_operator(n = 1)
    return @operator_stack.pop if n == 1

    @operator_stack.pop n
  end

  public

  def parse(mark = nil)
    @last_element = :initial
    end_predicate = end?(mark) if mark
    until block_given? ? (yield @context.peek) : end_predicate.call(@context.peek)
      token = @context.next
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
          if @context.peek.text == '['
            expect_mark '['
            e = Expression.new(@context).parse('[]')
            expect_mark ']'
            next push_operand(ArrayElement.new(token.text, e))
          end
          # subroutine call
          if @context.peek.text == '('
            expect_mark '('
            expr_list = ExpressionList.new(@context).parse
            expect_mark ')'
            next push_operand(SubroutineCall.new(token.text, expr_list))
          end

          # object method call
          if @context.peek.text == '.'
            object_name = token.text
            expect_mark '.'
            subroutine_name = expect_identifier
            raise "A pair of () are required after #{object_name}.#{subroutine_name}" unless mark? '('

            expect_mark '('
            expr_list = ExpressionList.new(@context).parse
            expect_mark ')'
            next push_operand(SubroutineCall.new(subroutine_name, expr_list, object_name))
          end
          # variable
          next push_operand(VariableReference.new(token.text))
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
          if @operator_stack&.empty? || @operator_stack.last == Operator::LEFT_PARENTHESIS
            next push_operator Operator.get_operator(token.text, @last_element)
          end

          until @operator_stack&.empty? || Operator.get_operator(token.text, @last_element).p > @operator_stack.last.p
            operator = pop_operator
            push_operand Expression.create(operator, pop_operand(operator.n))
          end
          push_operator Operator.get_operator(token.text, @last_element)
        end
      end
    end
    until @operator_stack&.empty?
      operator = pop_operator
      push_operand Expression.create(operator, pop_operand(operator.n))
    end
    return nil if @operand_stack.empty?

    return @operand_stack.last if @operand_stack.last.instance_of? Expression

    @operands = []
    operands << @operand_stack.last
    self
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

class ArrayElement < ASTNodeBase
  include Term
  attr_reader :var_name, :index_expression

  def initialize(var_name, index_expression)
    @var_name = var_name
    @index_expression = index_expression
  end
end

class SubroutineCall < ASTNodeBase
  include Term
  attr_reader :object, :subroutine_name, :expression_list

  def initialize(subroutine_name, expression_list, object = nil)
    @object = object
    @subroutine_name = subroutine_name.to_sym
    @expression_list = expression_list
  end
end

class VarDec < ASTNode
  attr_reader :type

  def name_list
    @name_list ||= []
  end

  def parse
    return nil unless keyword? 'var'

    expect_keyword 'var'
    @type = expect_var_type.to_sym
    name_list << expect_identifier.to_sym
    while mark? ','
      expect_mark ','
      name_list << expect_identifier.to_sym
    end
    expect_mark ';'
    self
  end
end

class ParameterList < ASTNode
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
    @type = type.to_sym
    @name = name.to_sym
  end
end

