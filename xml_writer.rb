require 'cgi'
require_relative 'syntax_analyzer'

class JackClass
  def to_xml
    <<-XML
    <class>
        <keyword>class</keyword>
            <identifier>#{class_name}</identifier>
            <symbol>{</symbol>
                #{class_var_decs.map(&:to_xml).join("\n")}
                #{subroutine_decs.map(&:to_xml).join("\n")}
            <symbol>}</symbol>
    </class>
    XML
  end
end

class ClassVarDec
  def to_xml
    label = type =~ /int|char|boolean/ ? 'keyword' : 'identifier'
    <<-XML
    <classVarDec>
        <keyword>#{kind}</keyword>
        <#{label}>#{type}</#{label}>
        #{var_list.map { |var| '<identifier>' + var + '</identifier>' }.join("\n<symbol>,</symbol>\n")}
        <symbol>;</symbol>
    </classVarDec>
    XML
  end
end

class SubroutineDec
  def to_xml
    label = return_type =~ /int|char|boolean|void/ ? 'keyword' : 'identifier'
    <<-XML
        <subroutineDec>
            <keyword>#{kind}</keyword>
            <#{label}>#{return_type}</#{label}> 
            <identifier>#{subroutine_name}</identifier>
            <symbol>(</symbol>
            #{parameter_list&.to_xml}
            <symbol>)</symbol>
            #{body.to_xml}
        </subroutineDec>
    XML
  end
end

class SubroutineBody
  def to_xml
    <<-XML
    <subroutineBody>
        <symbol>{</symbol>
        #{var_dec_list.map(&:to_xml).join("\n")}
        <statements>
          #{statements.map(&:to_xml).join("\n")}
        </statements>
        <symbol>}</symbol>
    </subroutineBody>
    XML
  end
end

class VarDec
  def to_xml
    label = type =~ /int|char|boolean/ ? 'keyword' : 'identifier'
    <<-XML
    <varDec>
        <keyword>var</keyword>
        <#{label}>#{type}</#{label}>
        #{name_list.map { |name| '<identifier>' + name + '</identifier>' }.join("\n<symbol>,</symbol>\n")}
        <symbol>;</symbol> 
    </varDec>
    XML
  end
end

class LetStatement
  def to_xml
    index_xml = "<symbol>[</symbol>\n#{index_expression.to_xml}<symbol>]</symbol>\n" if index_expression
    <<-XML
      <letStatement>
        <keyword>let</keyword>
        <identifier>#{var_name}</identifier>
        #{index_xml}
        <symbol>=</symbol>
        #{value_expression.to_xml}
        <symbol>;</symbol>
      </letStatement>
    XML
  end
end

class SimpleTerm
  def to_xml
    class_name = self.class.to_s.sub(/^./, &:downcase)
    class_name = 'identifier' if class_name == 'variableReference'
    class_name = 'keyword' if class_name == 'keywordConstant'
    <<-XML
      <term>
        <#{class_name}>#{@value.gsub(/"/, '')}</#{class_name}>
      </term>
    XML
  end
end
class ArrayElement
  def to_xml
    <<-XML
    <term>
      <identifier>#{var_name}</identifier>
      <symbol>[</symbol>
      #{index_expression.to_xml}
      <symbol>]</symbol>
    </term>
    XML
  end
end

class Expression
  def to_xml
    if operands && operands.size > 1
      if operands.first.instance_of?(Expression)
        symbol_begin = "<term><symbol>(</symbol>\n"
        symbol_end = "<symbol>)</symbol></term>\n"
      end
      first_operand_xml = "\n#{symbol_begin}#{operands.first.to_xml}\n#{symbol_end}"
    end
    symbol_begin = ''
    symbol_end = ''
    if operands.last.instance_of?(Expression)
      symbol_begin = "<term><symbol>(</symbol>\n"
      symbol_end = "<symbol>)</symbol></term>\n"
    end
    last_operand_xml = "\n#{symbol_begin}#{operands.last.to_xml}\n#{symbol_end}"
    if operands.size == 1 && operator
      term_begin = '<term>'
      term_end = '</term>'
    end

    <<-XML
    <expression>
      #{first_operand_xml}
      #{term_begin}
      #{operator&.to_xml}
      #{last_operand_xml}
      #{term_end}
    </expression>
    XML
  end
end

class Operator
  def to_xml
    <<-XML
    <symbol>#{CGI::escapeHTML(op)}</symbol>
    XML
  end
end

class IfStatement
  def to_xml
    unless else_statements.empty?
      else_xml = <<-XML
        <keyword>else</keyword>
        <symbol>{</symbol>
        <statements>
          #{else_statements.map(&:to_xml).join("\n")}
        </statements>
        <symbol>}</symbol>
      XML
    end
    <<-XML
    <ifStatement>
      <keyword>if</keyword>
      <symbol>(</symbol>
      #{condition_expression.to_xml}
      <symbol>)</symbol>
      <symbol>{</symbol>
      <statements>
        #{statements.map(&:to_xml).join("\n")}
      </statements>
      <symbol>}</symbol>
      #{else_xml}
    </ifStatement>
    XML
  end
end

class WhileStatement
  def to_xml
    <<-XML
    <whileStatement>
      <keyword>while</keyword>
      <symbol>(</symbol>
      #{condition_expression.to_xml}
      <symbol>)</symbol>
      <symbol>{</symbol>
      <statements>
        #{statements.map(&:to_xml).join("\n")}
      </statements>
      <symbol>}</symbol>
    </whileStatement>
    XML
  end
end

class DoStatement
  def to_xml
    <<-XML
    <doStatement>
      <keyword>do</keyword>
      #{subroutine_call.to_xml.strip[7..-8]}
      <symbol>;</symbol>
    </doStatement>
    XML
  end
end

class ReturnStatement
  def to_xml
    <<-XML
    <returnStatement>
      <keyword>return</keyword>
      #{return_expression&.to_xml} 
      <symbol>;</symbol>
    </returnStatement>
    XML
  end
end

class SubroutineCall
  def to_xml
    if object
      obj_xml = "\n<identifier>#{object}</identifier>\n<symbol>.</symbol>\n"
    end
    <<-XML
    <term>
    #{obj_xml}
    <identifier>#{subroutine_name}</identifier>
    <symbol>(</symbol>
    #{expression_list&.to_xml}
    <symbol>)</symbol>
    </term>
    XML
  end
end

class ExpressionList
  def to_xml
    to_xml_join = expressions.map(&:to_xml).join("\n<symbol>,</symbol>\n")
    <<-XML
    <expressionList>
      #{to_xml_join}
    </expressionList>
    XML
  end
end

class ParameterList
  def to_xml
    values_xml = values.map(&:to_xml).join("\n<symbol>,</symbol>\n")
    <<-XML
    <parameterList>
      #{values_xml}
    </parameterList>
    XML
  end
end

class VariableDef
  def to_xml
    label = type =~ /int|char|boolean/ ? 'keyword' : 'identifier'
    <<-XML
      <#{label}>#{type}</#{label}>
      <identifier>#{name}</identifier>
    XML
  end
end

