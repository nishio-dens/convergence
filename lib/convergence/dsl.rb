require 'convergence/table'

class Convergence::DSL
  attr_accessor :tables, :raw_sqls, :current_dir_path

  def initialize
    @tables = {}
    @raw_sqls = []
  end

  def create_table(table_name, options = {}, &block)
    table = Convergence::Table.new(table_name.to_s, options)
    block.call(table)
    @tables[table_name.to_s] = table
    table
  end

  # Execute an arbitrary SQL statement that the DSL has no dedicated syntax for
  # (e.g. triggers, stored procedures, data backfills). Unlike create_table,
  # this is not diffed against the current schema: it runs every time the
  # schema file is applied, so the SQL itself must be idempotent.
  def execute(sql)
    @raw_sqls << sql
  end

  def include(path)
    next_dir_path = File.dirname("#{@current_dir_path}/#{path}")
    included = Convergence::DSL.parse_dsl(File.open("#{current_dir_path}/#{path}").read, next_dir_path)
    @tables.merge!(included.tables)
    @raw_sqls.concat(included.raw_sqls)
  end

  def self.parse(code, current_dir_path)
    parse_dsl(code, current_dir_path).tables
  end

  def self.parse_dsl(code, current_dir_path)
    parser = new
    parser.current_dir_path = current_dir_path
    parser.instance_eval(code)
    parser
  end
end
