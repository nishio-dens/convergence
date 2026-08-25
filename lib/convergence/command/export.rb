require 'convergence/command'
require 'convergence/dumper'
require 'convergence/default_parameter'

class Convergence::Command::Export < Convergence::Command
  def execute
    tables = Convergence::DefaultParameter.remove_database_default_parameter(dumper.dump, database_adapter)
    msg = if @opts[:dump_rails_migration]
            dump_rails_migration(tables)
          else
            Convergence::Dumper.new.dump_dsl(tables)
          end
    logger.output(msg)
    msg
  end

  private

  def dump_rails_migration(tables)
    filename = @opts[:filename] || 'convergence_migration'
    class_name = camelize(filename)
    migration_filename = "#{Time.now.strftime('%Y%m%d%H%M%S')}_#{filename}.rb"
    body = Convergence::Dumper.new.dump_rails_migration(tables, class_name)
    "# Filename: #{migration_filename}\n#{body}"
  end

  def camelize(name)
    name.to_s.split(/[_-]/).reject(&:empty?).map { |part| part[0].upcase + part[1..].to_s }.join
  end
end
