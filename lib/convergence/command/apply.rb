require 'benchmark'
require 'pathname'

class Convergence::Command::Apply < Convergence::Command
  def validate!
    fail ArgumentError.new('--config required') if @config.nil?
    fail ArgumentError.new('--input required') unless @opts[:input]
  end

  def execute
    validate!
    current_dir_path = Pathname.new(@opts[:input]).realpath.dirname
    input_tables, hooks = Convergence::DSL.parse(File.open(@opts[:input]).read, current_dir_path)
    current_tables = dumper.dump

    sql_executor = Convergence::SqlExecutor.new(@opts, config: @config)

    hook_executor = Convergence::HookExecutor.new(input_tables, current_tables, sql_executor, hooks)
    hook_executor.execute

    current_tables = dumper.dump if hook_executor.before_apply?

    sql = generate_sql(input_tables, current_tables)
    sql_executor.execute(sql)
  end

  def execute_sql(input_tables, current_tables, sql_executor)
    sql_executor.execute(sql)
  end

  def generate_sql(input_tables, current_tables)
    current_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(current_tables, database_adapter)
    input_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(input_tables, database_adapter)
    delta = Convergence::Diff.new.diff(current_tables_with_full_option, input_tables_with_full_option)
    sql_generator.generate(input_tables_with_full_option, delta, current_tables_with_full_option)
  end
end
