require 'benchmark'

class Convergence::Command::Apply < Convergence::Command
  def validate!
    fail ArgumentError.new('--config required') if @config.nil?
    fail ArgumentError.new('--input required') unless @opts[:input]
  end

  def execute
    validate!
    input_tables = Convergence::DSL.parse(File.open(@opts[:input]).read)
    current_tables = dumper.dump
    execute_sql(input_tables, current_tables)
  end

  def execute_sql(input_tables, current_tables)
    sql = generate_sql(input_tables, current_tables)
    unless sql.strip.empty?
      sql = <<-SQL
SET FOREIGN_KEY_CHECKS=0;
      #{sql}
SET FOREIGN_KEY_CHECKS=1;
      SQL
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

  def generate_sql(input_tables, current_tables)
    current_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(current_tables, database_adapter)
    input_tables_with_full_option =
      Convergence::DefaultParameter.append_database_default_parameter(input_tables, database_adapter)
    delta = Convergence::Diff.new.diff(current_tables_with_full_option, input_tables_with_full_option)
    sql_generator.generate(input_tables_with_full_option, delta)
  end
end
