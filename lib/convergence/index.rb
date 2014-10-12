class Convergence::Index
  attr_accessor :index_name, :index_columns, :options

  def initialize(index_name, index_columns, options)
    @index_name = index_name
    @index_columns = [index_columns].flatten.map(&:to_s)
    @options = { name: @index_name }.merge(options)
  end
end
