require 'benchmark'

class Convergence::SqlExecutor < Convergence::Command
  def execute(sql)
    unless sql.strip.empty?
      sql = <<-SQL
SET FOREIGN_KEY_CHECKS=0;
      #{sql}
SET FOREIGN_KEY_CHECKS=1;
      SQL
    end
    sql.split(';').each do |q2|
      q = q2.strip
      unless q.empty?
        begin
          q = q + ';'
          time = Benchmark.realtime { connector.client.query(q) }
          logger.output q
          logger.output "  --> #{time}s"
        rescue => e
          logger.output 'Invalid Query Exception >>>'
          logger.output q
          logger.output '<<<'
          throw e
        end
      end
    end
  end
end
