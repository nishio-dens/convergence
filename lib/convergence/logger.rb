require 'logger'
class Convergence::Logger < Logger
  def initialize
    super($default_output || $stdout)
    self.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    self.level = Logger::INFO
  end

  def output(msg)
    info(msg)
  end
end
