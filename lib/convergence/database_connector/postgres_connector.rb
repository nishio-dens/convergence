require 'pg'
require 'convergence/database_connector'

class Convergence::DatabaseConnector::PostgresConnector
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def client(database_name = @config.database)
    @clients ||= {}
    @clients[database_name] ||= PG::Connection.new(
      host: @config.host,
      port: @config.port,
      user: @config.username,
      password: @config.password,
      dbname: database_name
    )
  end

  def schema_client
    client
  end
end
