require 'benchmark'
require 'pathname'
require 'convergence/command'
require 'convergence/dsl'
require 'convergence/default_parameter'
require 'convergence/diff'

class Convergence::Command::Apply < Convergence::Command
  def execute
    current_dir_path = Pathname.new(@opts[:input]).realpath.dirname
    dsl = Convergence::DSL.parse_dsl(File.open(@opts[:input]).read, current_dir_path)
    current_tables = dumper.dump
    execute_sql(dsl.tables, current_tables, dsl.raw_sqls)
  end

  def generate_sql(input_tables, current_tables, raw_sqls = [])
    current_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(current_tables, database_adapter)
    input_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(input_tables, database_adapter)
    delta = Convergence::Diff
      .new(ignore_auto_increment: @opts[:ignore_auto_increment])
      .diff(current_tables_with_full_option, input_tables_with_full_option)
    sql = sql_generator.generate(
      input_tables_with_full_option,
      delta,
      current_tables_with_full_option,
      safe_migration: @opts[:safe_migration]
    )
    append_raw_sqls(sql, raw_sqls)
  end

  private

  def append_raw_sqls(sql, raw_sqls)
    return sql if raw_sqls.empty?
    raw_sql_block = raw_sqls.map { |q| q.strip.end_with?(';') ? q.strip : "#{q.strip};" }.join("\n")
    [sql, raw_sql_block].reject(&:empty?).join("\n")
  end

  def sql_generator
    @sql_generator ||= case database_adapter
                       when 'mysql', 'mysql2'
                         require 'convergence/sql_generator/mysql_generator'
                         SQLGenerator::MysqlGenerator.new
                       when 'postgresql', 'postgres', 'pg'
                         require 'convergence/sql_generator/postgres_generator'
                         SQLGenerator::PostgresGenerator.new
                       when 'sqlite3', 'sqlite'
                         require 'convergence/sql_generator/sqlite_generator'
                         SQLGenerator::SqliteGenerator.new
                       else
                         fail NotImplementedError.new('unknown database adapter')
                       end
  end

  def wrap_with_constraint_pragma(sql)
    case database_adapter
    when 'mysql', 'mysql2'
      <<-SQL
SET FOREIGN_KEY_CHECKS=0;
      #{sql}
SET FOREIGN_KEY_CHECKS=1;
      SQL
    else
      sql
    end
  end

  def execute_sql(input_tables, current_tables, raw_sqls = [])
    sql = generate_sql(input_tables, current_tables, raw_sqls)
    unless sql.strip.empty?
      sql = wrap_with_constraint_pragma(sql)
    end
    sql.split(';').each do |q2|
      q = q2.strip
      unless q.empty?
        begin
          q = q + ';'
          time = Benchmark.realtime { connector.client.query(q) }
          logger.output q
          logger.output "  --> #{time}s"
        rescue => e
          logger.output 'Invalid Query Exception >>>'
          logger.output q
          logger.output '<<<'
          throw e
        end
      end
    end
  end
end
