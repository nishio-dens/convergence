require 'sqlite3'
require 'convergence/database_connector'

class Convergence::DatabaseConnector::SqliteConnector
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def client(database_name = @config.database)
    @clients ||= {}
    @clients[database_name] ||= SQLite3::Database.new(database_name).tap do |db|
      db.results_as_hash = true
      db.execute('PRAGMA foreign_keys = ON')
    end
  end

  def schema_client
    client
  end
end
