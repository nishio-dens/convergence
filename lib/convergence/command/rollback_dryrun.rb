require 'pathname'
require 'convergence/command'
require 'convergence/command/apply'
require 'convergence/dsl'
require 'convergence/default_parameter'

class Convergence::Command::RollbackDryrun < Convergence::Command
  def execute
    current_dir_path = Pathname.new(@opts[:input]).realpath.dirname
    input_tables = Convergence::DSL.parse(File.open(@opts[:input]).read, current_dir_path)
    current_tables = dumper.dump

    output_sql(current_tables, input_tables)
  end

  private

  def output_sql(input_tables, current_tables)
    msg = Convergence::Command::Apply
      .new(@opts, config: @config)
      .generate_sql(input_tables, current_tables)
      .split("\n")
      .map { |v| '# ' + v }
      .join("\n")
    logger.output(msg)
    msg
  end
end
