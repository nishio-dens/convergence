class Convergence::DefaultParameter
  def initialize(adapter)
    case adapter.downcase
    when 'mysql', 'mysql2'
      @parameter_klass = Convergence::DefaultParameter::MysqlDefaultParameter.new
    else
      fail NotImplementedError.new("unknown adapter #{config.adapter}.")
    end
  end

  def remove_default_parameter(table)
    @parameter_klass.remove_default_parameter(table)
  end

  def append_default_parameter(table)
    @parameter_klass.append_default_parameter(table)
  end

  def self.remove_database_default_parameter(tables, adapter)
    values = tables.values.map do |table|
      { table.table_name => Convergence::DefaultParameter.new(adapter).remove_default_parameter(table) }
    end
    values.reduce { |a, e| a.merge(e) }
  end

  def self.append_database_default_parameter(tables, adapter)
    values = tables.values.map do |table|
      { table.table_name => Convergence::DefaultParameter.new(adapter).append_default_parameter(table) }
    end
    values.reduce { |a, e| a.merge(e) }
  end
end
