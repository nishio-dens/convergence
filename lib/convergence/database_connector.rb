class Convergence::DatabaseConnector
  attr_reader :connector

  def initialize(config)
    @connector =
      case config.adapter
      when 'mysql'
        Convergence::DatabaseConnector::MysqlConnector.new(config)
      else
        fail NotImplementedError.new("#{config.adapter} not supported yet")
      end
  end

  def client
    @connector.client
  end

  def schema_client
    @connector.schema_client
  end

  def config
    @connector.config
  end
end
