module SymbolTable
  include Enumerable
  attr_accessor :parent
  attr_accessor :table_name
  attr_accessor :kind

  def table
    @table ||= {}
  end

  def var_count(kind)
    table.values.select { |var| var.kind == kind }.size
  end

  def type?(name)
    table[name]&.type
  end

  # static, field, local, argument
  def kind?(name)
    table[name]&.kind
  end

  def index?(name)
    table[name]&.index
  end

  def [](key)
    table[key.to_sym] || (parent[key] if parent)
  end

  def each
    table&.each unless block_given?
    table&.each do |p|
      yield p
    end
  end

  def define(name, var_kind, type)


    raise "Symbol #{name} was already defined in #{table_name}" if table.include? name

    index = kind == :method && var_kind == :argument ? 1 : 0
    max_index = table.values.select { |s| s.kind == var_kind }.max_by(&:index)&.index
    index = max_index + 1 if max_index

    table[name] = SymbolEntry.new(name, var_kind, type, index)
  end

  def next_counter
    @counter ||= -1
    @counter += 1
  end

  class SymbolEntry
    attr_reader :name
    attr_reader :kind
    attr_reader :type
    attr_reader :index

    def initialize(name, kind, type, index)
      @name = name
      @kind = kind
      @type = type
      @index = index
    end
  end
end
