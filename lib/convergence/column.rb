class Convergence::Column
  attr_accessor :type, :column_name, :options

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
  )
  FLOATING_POINT_COLUMN_TYPE = %i(
    float
    double
    decimal
  )

  def initialize(type, column_name, options = {})
    @type = type
    @column_name = column_name
    @options = options
  end
end
