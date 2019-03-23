require 'convergence/command'
require 'convergence/dumper'
require 'convergence/default_parameter'

class Convergence::Command::Export < Convergence::Command
  def execute
    tables = Convergence::DefaultParameter.remove_database_default_parameter(dumper.dump, database_adapter)
    msg = Convergence::Dumper.new.dump_dsl(tables)
    logger.output(msg)
    msg
  end
end
