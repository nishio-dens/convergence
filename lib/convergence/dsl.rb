class Convergence::DSL
  attr_accessor :tables, :current_dir_path, :hooks

  def initialize
    @tables = {}
    @hooks = {}
  end

  def create_table(table_name, options = {}, &block)
    table = Convergence::Table.new(table_name.to_s, options)
    block.call(table)
    @tables[table_name.to_s] = table
    table
  end

  def include(path)
    next_dir_path = File.dirname("#{@current_dir_path}/#{path}")
    @tables.merge!(Convergence::DSL.parse(File.open("#{current_dir_path}/#{path}").read, next_dir_path))
  end

  def before_apply(&block)
    hooks[:before_apply] ||= []
    hooks[:before_apply] << block
  end

  def self.parse(code, current_dir_path)
    parser = new
    parser.current_dir_path = current_dir_path
    parser.instance_eval(code)
    [parser.tables, parser.hooks]
  end
end
