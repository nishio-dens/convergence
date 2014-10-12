class Convergence::ForeignKey
  attr_accessor :key_name, :from_columns, :to_table, :to_columns, :options

  def initialize(key_name, from_columns, to_table, to_columns, options)
    @key_name = key_name
    @from_columns = [from_columns].flatten.map(&:to_s)
    @to_table = to_table
    @to_columns = [to_columns].flatten.map(&:to_s)
    @options = { name: @key_name }.merge(options)
  end
end
