class Convergence::HookDsl
  attr_accessor :input_tables, :current_tables

  def initialize(input_tables, current_tables, sql_executor)
    @input_tables = input_tables
    @current_tables = current_tables
    @sql_executor = sql_executor
  end

  def execute_sql(query)
    @sql_executor.execute(query)
  end

  def table_exists?(_table_name)
    table_name = _table_name.to_s
    !@current_tables[table_name].nil?
  end

  def column_exists?(_table_name, _column_name)
    table_name = _table_name.to_s
    column_name = _column_name.to_s

    return false unless table_exists?(table_name)
    !@current_tables[table_name].columns[column_name].nil?
  end
end
