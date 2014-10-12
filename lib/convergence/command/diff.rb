class Convergence::Command::Diff < Convergence::Command
  def validate!
    unless @opts[:diff].size == 2
      fail ArgumentError.new('diff required two arguments')
    end
  end

  def execute
    validate!
    from = Convergence::DefaultParameter.remove_database_default_parameter(from_tables, database_adapter)
    to = Convergence::DefaultParameter.remove_database_default_parameter(to_tables, database_adapter)
    msg = Convergence::PrettyDiff.new(from, to).output
    logger.output(msg)
    msg
  end

  private

  def from_tables
    Convergence::DSL.parse(File.open(@opts[:diff][0]).read)
  end

  def to_tables
    Convergence::DSL.parse(File.open(@opts[:diff][1]).read)
  end
end
