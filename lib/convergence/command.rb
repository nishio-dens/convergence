require 'convergence/config'
require 'convergence/logger'
require 'convergence/database_connector'

class Convergence::Command
  def initialize(opts, config: nil)
    @opts = opts
    if config.nil?
      @config = Convergence::Config.load(opts[:config]) if @opts[:config]
    else
      @config = config
    end
  end

  private

  def database_adapter
    @config.nil? ? 'mysql' : @config.adapter
  end

  def connector
    @connector ||= Convergence::DatabaseConnector.new(@config)
  end

  def dumper
    @dumper ||= case database_adapter
                when 'mysql', 'mysql2'
                  require 'convergence/dumper/mysql_schema_dumper'
                  Convergence::Dumper::MysqlSchemaDumper.new(connector)
                else
                  fail NotImplementedError.new('unknown database adapter')
                end
  end

  def sql_generator
    @sql_generator ||= case database_adapter
                       when 'mysql', 'mysql2'
                         require 'convergence/sql_generator/mysql_generator'
                         SQLGenerator::MysqlGenerator.new
                       else
                         fail NotImplementedError.new('unknown database adapter')
                       end
  end

  def logger
    @logger ||= Convergence::Logger.new
  end
end
