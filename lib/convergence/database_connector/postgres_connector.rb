require 'pg'

class Convergence::DatabaseConnector::PostgresConnector
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def client(database_name = @config.database)
    @pg ||= PG.connect(
      @config.host,
      @config.port,
      '',
      '',
      database_name,
      @config.username,
      @config.password
    )
  end

  def schema_client(database_name = @config.database)
    @schema_pg ||= PG.connect(
      @config.host,
      @config.port,
      '',
      '',
      database_name,
      @config.username,
      @config.password
    )
  end
end
