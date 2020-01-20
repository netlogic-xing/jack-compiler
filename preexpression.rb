exp = '1+((2+3)*4)-5'
class Node
  attr_reader :value, :children
end
op_priority = {'(' => -1, ')' => -1, '*' => -2, '/' => -2, '+' => -3, '-' => -3}
operator_stack = []
operand_stack = []
exp.each_char do |x|
  if x =~ /\d/
    operand_stack.push x
    next
  end
  case x
  when '('
    operator_stack.push x
  when ')'
    operand_stack.push "#{operator_stack.pop}#{operand_stack.pop(2).join}" until operator_stack.last <= '('
    operator_stack.pop # pop ')'
  else
    if operator_stack.empty? || operator_stack.last == '('
      operator_stack.push x
      next
    end
    until operator_stack.empty?||op_priority[x] > op_priority[operator_stack.last]
      operand_stack.push "#{operator_stack.pop}#{operand_stack.pop(2).join}"
    end
    operator_stack.push x
  end
end
operand_stack.push "#{operator_stack.pop}#{operand_stack.pop(2).join}" until operator_stack.empty?
puts operand_stack


