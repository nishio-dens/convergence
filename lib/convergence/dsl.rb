class Convergence::DSL
  attr_accessor :tables

  def initialize
    @tables = {}
  end

  def create_table(table_name, options = {}, &block)
    table = Convergence::Table.new(table_name, options)
    block.call(table)
    @tables[table_name.to_s] = table
    table
  end

  def self.parse(code)
    parser = new
    parser.instance_eval(code)
    parser.tables
  end
end
