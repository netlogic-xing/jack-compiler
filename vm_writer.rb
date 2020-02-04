module VMWriter
  #attr_accessor :vm_file

  def push(segment, index)
    vm_file.puts "push #{segment} #{index}"
  end

  def pop(segment, index)
    vm_file.puts "pop #{segment} #{index}"
  end

  %w[add sub neg eq gt lt _and _or _not _return].each do |cmd|
    define_method(cmd) { vm_file.puts cmd.sub(/_/, '') }
  end

  %w[label goto if_goto].each do |cmd|
    define_method(cmd) { |label| vm_file.puts "#{cmd.sub(/_/, '-')} #{label}" }
  end

  def call(name, n_args)
    vm_file.puts "call #{name} #{n_args}"
  end

  def function(name, n_local)
    vm_file.puts "function #{name} #{n_local}"
  end

  def mul
    call 'Math.multiply', 2
  end

  def div
    call 'Math.divide', 2
  end

  def new_string(string)
    string = string.gsub(/"/, '')
    push :constant, string.length
    call 'String.new', 1
    string.each_char do |c|
      push :constant, c.ord
      call 'String.appendChar', 2
    end
  end
end
class ASTNodeBase
  include VMWriter
end
class JackClass

  def display_symbol_table
    puts "***#{class_name}'s symbol table:"
    each do |name, symbol_entry|
      puts "   #{symbol_entry.name}, #{symbol_entry.type}, #{symbol_entry.kind}"
    end
    subroutine_decs.each do |sub|
      puts "------#{sub.subroutine_name}'s symbol table"
      sub.each do |name, symbol_entry|
        puts "      #{symbol_entry.name}, #{symbol_entry.type}, #{symbol_entry.kind}"
      end
    end
  end

  def write_vm_code
    subroutine_decs.each do |sub|
      $symbol_table_stack.push sub
      n_args = sub.var_count(:local)
      function("#{class_name}.#{sub.subroutine_name}", n_args)
      if sub.kind == :constructor
        push :constant, var_count(:field)
        call 'Memory.alloc', 1
        pop :pointer, 0
      end
      if sub.kind == :method
        push :argument, 0
        pop :pointer, 0
      end
      sub.write_vm_code
      $symbol_table_stack.pop
    end
  end
end

class SubroutineDec
  def write_vm_code
    body.statements.each { |stmt| stmt.write_vm_code }
  end
end

class LetStatement
  def write_vm_code
    vm_file.puts "#Let begin #{var_name}"
    symbol = $symbol_table_stack.last[var_name]
    puts "#{var_name} #{$symbol_table_stack.last.table_name}" unless symbol
    segment = symbol.kind
    segment = :this if segment == :field
    if index_expression
      push segment, symbol.index
      index_expression.write_vm_code
      add
      pop :pointer, 1
      value_expression.write_vm_code
      pop :that, 0
      vm_file.puts "#Let end array element"
      return
    end
    value_expression.write_vm_code
    pop segment, symbol.index
    vm_file.puts "#Let end"
  end
end

class IfStatement
  def write_vm_code
    condition_expression.write_vm_code
    cur_obj = $symbol_table_stack.last
    index = cur_obj.next_counter
    if_goto "#{cur_obj.table_name}-#{index}-true"
    else_statements&.each { |stmt| stmt.write_vm_code }
    goto "#{cur_obj.table_name}-#{index}-end"
    label "#{cur_obj.table_name}-#{index}-true"
    statements.each { |stmt| stmt.write_vm_code }
    label "#{cur_obj.table_name}-#{index}-end"
  end
end

class WhileStatement
  def write_vm_code
    cur_obj = $symbol_table_stack.last
    index = cur_obj.next_counter
    label "#{cur_obj.table_name}-#{index}-begin"
    condition_expression.write_vm_code
    if_goto "#{cur_obj.table_name}-#{index}-true"
    goto "#{cur_obj.table_name}-#{index}-end"
    label "#{cur_obj.table_name}-#{index}-true"
    statements.each { |stmt| stmt.write_vm_code }
    goto "#{cur_obj.table_name}-#{index}-begin"
    label "#{cur_obj.table_name}-#{index}-end"
  end
end

class DoStatement
  def write_vm_code
    subroutine_call.write_vm_code
    pop :temp, 0
  end
end

class ReturnStatement
  def write_vm_code
    return_expression&.write_vm_code
    _return
  end
end
class Expression
  def write_vm_code
    operands.each { |o| o.write_vm_code }
    operator&.write_vm_code
  end
end

class IntegerConstant
  def write_vm_code
    push(:constant, value)
  end
end

class StringConstant
  def write_vm_code
    new_string value
  end
end

class KeywordConstant
  def write_vm_code
    case value
    when 'true'
      push :constant, 0
      _not
    when 'false'
      push :constant, 0
    when 'null'
      push :constant, 0
    when 'this'
      push :pointer, 0
    end
  end
end

# static, field, local, argument
class VariableReference
  def write_vm_code
    symbol = $symbol_table_stack.last[value]
    segment = symbol.kind
    segment = :this if segment == :field
    push segment, symbol.index
  end
end

class ArrayElement
  def write_vm_code
    symbol = $symbol_table_stack.last[var_name]
    raise "Unknown variable #{var_name} in #{$symbol_table_stack.last.table_name}" unless symbol

    segment = symbol.kind
    segment = :this if segment == :field
    push segment, symbol.index
    index_expression.write_vm_code
    add
    pop :pointer, 1
    push :that, 0
  end
end

class SubroutineCall
  def write_vm_code
    n_args = expression_list.expressions.size
    symbol = $symbol_table_stack.last[object] if object
    if symbol
      segment = symbol.kind
      segment = :this if segment == :field

      push segment, symbol.index
      clazz = symbol.type
      n_args += 1
    end
    clazz = object unless symbol
    clazz = $symbol_table_stack.last.parent.table_name unless object
    full_name = "#{clazz}.#{subroutine_name}"
    unless object
      sub_dec = $symbol_table_stack.last.parent.subroutine_decs.find { |sub| sub.subroutine_name == subroutine_name }
      raise "Unknown subroutine #{subroutine_name} called in #{$symbol_table_stack.last.table_name}" unless sub_dec

      n_args += 1
      push :pointer, 0
    end
    expression_list.expressions.each { |e| e.write_vm_code }
    call full_name, n_args
  end
end

class Operator
  def NOT.write_vm_code
    _not
  end

  def NEG.write_vm_code
    neg
  end

  def PRODUCT.write_vm_code
    mul
  end

  def DIVIDE.write_vm_code
    div
  end

  def PLUS.write_vm_code
    add
  end

  def MINUS.write_vm_code
    sub
  end

  def AND.write_vm_code
    _and
  end

  def OR.write_vm_code
    _or
  end

  def GT.write_vm_code
    gt
  end

  def LT.write_vm_code
    lt
  end

  def EQ.write_vm_code
    eq
  end
end
