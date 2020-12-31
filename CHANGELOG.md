## Convergence 1.0.5 (December 31, 2020) ##

* Update dependent gem (PR: #80)

  *nishio-dens*

## Convergence 1.0.4 (September 8, 2020) ##

* Support diff-lcs 1.4 (PR: #75 #76)

  *yujideveloper*

* Fix warning on Ruby 2.6 and later (PR: #77)

  *yujideveloper*

## Convergence 1.0.3 (January 8, 2020) ##

* Support json column (PR: #70)

  *nishio-dens*

## Convergence 1.0.2 (May 24, 2019) ##

* Support ssl connections (PR: #69)

  *yujideveloper*

## Convergence 1.0.1 (September 27, 2018) ##

* Add Rollback Dryrun command (PR: #64)

  *nishio-dens*

## Convergence 1.0.0 (August 28, 2018) ##

* [BREAKING CHANGE] Change flag style command to sub-command style (PR: #60)

  A flag style command has been deprecated

      e.g. convergence -c database.yml -i example.schema --apply

  Introduce a sub command style.

      e.g. convergence apply example.schema -c database.yml

  *yujideveloper*

## Convergence 0.2.7 (August 20, 2018) ##

* Fix issues of Convergence::Config (PR: #58)

  *yujideveloper*

## Convergence 0.2.6 (March 4, 2018) ##

* Improve dryrun output (PR: #55)

  *yujideveloper*

* Support MySQL identifiers that require quotes in Ruby symbol syntax on export dsl (PR: #56)

  *yujideveloper*

* Output help message when executed without option (PR: #57)

  *yujideveloper*

## Convergence 0.2.5 (December 21, 2017) ##

* Bug Fix Diff option does not work fine (PR: #50)

  *yujideveloper*

* Bug Fix NoMethodError (PR: #51)

  *yujideveloper*

* Change requires ruby version (>= 2.3.0)

  *yujideveloper*

## Convergence 0.2.4 (December 20, 2017) ##

* Bug Fix default: "" to default: nil does not work fine

  *nishio-dens*

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
