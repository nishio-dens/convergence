class Convergence::Column
  attr_accessor :type, :column_name, :options, :renamed_from

  COLUMN_TYPE = %i(
    tinyint
    smallint
    mediumint
    int
    bigint
    float
    double
    decimal
    char
    varchar
    tinyblob
    blob
    mediumblob
    longblob
    tinytext
    text
    mediumtext
    longtext
    enum
    set
    date
    time
    datetime
    timestamp
    year
    json
  )
  FLOATING_POINT_COLUMN_TYPE = %i(
    float
    double
    decimal
  )

  def initialize(type, column_name, options = {})
    @type = type
    @column_name = column_name
    @renamed_from = options[:renamed_from]&.to_s
    @options = options.reject { |k| k == :renamed_from }
  end
end
