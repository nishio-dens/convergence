## Convergence 0.2.3 (November 29, 2017) ##

* Change default column limit (PR: #31)

  Example:
      
      # Schema
      create_table "sample" do |t|
        t.tinyint :t
        t.smallint :s
        t.mediumint :m
        t.int :i
        t.bigint :b
      end

      # Before
      CREATE TABLE `sample` (
        `t` tinyint(3) NOT NULL,
        `s` smallint(5) NOT NULL,
        `m` mediumint(8) NOT NULL,
        `i` int(11) NOT NULL,
        `b` bigint(19) NOT NULL
      ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;

      # After
      CREATE TABLE `sample` (
        `t` tinyint(4) NOT NULL,
        `s` smallint(6) NOT NULL,
        `m` mediumint(9) NOT NULL,
        `i` int(11) NOT NULL,
        `b` bigint(20) NOT NULL
      ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;

  *yujideveloper*

* Change supported ruby version from 2.0.0 to 2.4.1 (PR: #35)

  *nishio-dens*

* Fix Deprecated Warnings (PR: #36)

  *nishio-dens*
