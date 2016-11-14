class Convergence::HookExecutor
  attr_accessor :input_tables, :current_tables, :hooks

  def initialize(input_tables, current_tables, sql_executor, hooks = {})
    @before_applied = false
    @input_tables = input_tables
    @current_tables = current_tables
    @sql_executor = sql_executor
    @hooks = hooks
  end

  def execute
    execute_before_apply
  end

  def before_apply?
    @before_applied
  end

  private

  def execute_before_apply
    return if hooks[:before_apply].nil? || hooks[:before_apply].empty?
    @hooks[:before_apply].each do |hook_function|
      dsl = Convergence::HookDsl.new(@input_tables, @current_tables, @sql_executor)
      self.instance_eval do
        hook_function.call(dsl)
      end
    end
    @before_applied = true
  end
end
