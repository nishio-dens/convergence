class Convergence::Table
  attr_accessor :table_name, :table_options, :columns, :indexes, :foreign_keys

  Convergence::Column::COLUMN_TYPE.each do |column_type|
    define_method "#{column_type}" do |column_name, options = {}|
      @columns[column_name.to_s] = Convergence::Column.new(column_type, column_name.to_s, options)
    end
  end

  def index(index_columns, options = {})
    index_name = options[:name]
    index_name = "index_#{table_name}_on_#{[index_columns].flatten.join('_')}" if index_name.nil?
    @indexes[index_name] = Convergence::Index.new(index_name, index_columns, options)
  end

  def foreign_key(key_columns, options = {})
    if options[:reference].nil? || options[:reference_column].nil?
      fail ArgumentError.new("#{@table_name} - #{key_columns}: require reference/reference_column parameters")
    end
    key_name = options[:name]
    key_name = "#{table_name}_#{[key_columns].flatten.join('_')}_fk" if key_name.nil?
    @foreign_keys[key_name] = Convergence::ForeignKey.new(
      key_name,
      key_columns,
      options[:reference],
      [options[:reference_column]].flatten,
      options.reject { |k, _v| k == :reference || k == :reference_column })
  end

  def initialize(table_name, options = {})
    @table_name = table_name
    @table_options = options
    @columns = {}
    @indexes = {}
    @foreign_keys = {}
  end
end
