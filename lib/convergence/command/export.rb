class Convergence::Command::Export < Convergence::Command
  def validate!
    if @config.nil?
      fail ArgumentError.new('--config required')
    end
  end

  def execute
    validate!
    tables = Convergence::DefaultParameter.remove_database_default_parameter(dumper.dump, database_adapter)
    msg = Convergence::Dumper.new.dump_dsl(tables)
    logger.output(msg)
    msg
  end
end
