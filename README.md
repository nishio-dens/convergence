# Convergence

Convergence is a pure-Ruby database schema migration tool.
Currently, This tool supports MySQL, PostgreSQL, and SQLite.

It defines DB Schema using Convergence DSL(like Rails DSL).
For more information about Convergence DSL, See below ['Detail About Convergence DSL'](#detail-about-convergence-dsl)


[![Gem Version](https://badge.fury.io/rb/convergence.svg)](https://badge.fury.io/rb/convergence)
[![Build Status](https://travis-ci.org/nishio-dens/convergence.svg?branch=master)](https://travis-ci.org/nishio-dens/convergence)

## Installation

Add this line to your application's Gemfile:

```
gem 'convergence'
```

and then execute

```
bundle
```

Or install it yourself as:

```
gem install convergence
```

## What's this?

```
$ mysql -u root -e 'create database example_database;'
$ cat database.yml

adapter: mysql
database: example_database
host: 127.0.0.1
username: root
password:

$ cat example.schema

create_table 'test_tables' do |t|
  t.int :id, primary_key: true, extra: 'auto_increment'
  t.varchar :name, limit: 100, null: true
  t.datetime :created_at
  t.datetime :updated_at

  t.index :name
end

$ convergence apply example.schema -c database.yml --dry-run

# CREATE TABLE `test_tables` (
#   `id` int(11) NOT NULL AUTO_INCREMENT,
#   `name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL,
#   `created_at` datetime NOT NULL,
#   `updated_at` datetime NOT NULL,
#   PRIMARY KEY (`id`),
#   KEY `index_test_tables_on_name` (`name`)
# ) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;

$ convergence apply example.schema -c database.yml

SET FOREIGN_KEY_CHECKS=0;
  --> 0.0005826340056955814s
CREATE TABLE `test_tables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_test_tables_on_name` (`name`)
) ENGINE=InnoDB ROW_FORMAT=Compact DEFAULT CHARACTER SET=utf8 COLLATE=utf8_general_ci;
  --> 0.017457014000683557s
SET FOREIGN_KEY_CHECKS=1;
  --> 0.00019878800230799243s

$ cat changed_example.schema

create_table 'test_tables', comment: 'Table Comment Test', engine: 'MyISAM' do |t|
  t.int :id, primary_key: true, extra: 'auto_increment'
  t.varchar :name, limit: 100, null: true
  t.datetime :created_at
  t.datetime :posted_at
end

$ convergence apply changed_example.schema -c database.yml --dry-run

# DROP INDEX `index_test_tables_on_name` ON `test_tables`;
# ALTER TABLE `test_tables`
#   DROP COLUMN `updated_at`;
# ALTER TABLE `test_tables`
#   ADD COLUMN `posted_at` datetime NOT NULL AFTER `created_at`;
# ALTER TABLE `test_tables` ENGINE=MyISAM COMMENT='Table Comment Test';

$ convergence apply changed_example.schema -c database.yml

SET FOREIGN_KEY_CHECKS=0;
  --> 0.0005331430002115667s
DROP INDEX `index_test_tables_on_name` ON `test_tables`;
  --> 0.010850776998267975s
ALTER TABLE `test_tables`
  DROP COLUMN `updated_at`;
  --> 0.025050114003533963s
ALTER TABLE `test_tables`
  ADD COLUMN `posted_at` datetime NOT NULL AFTER `created_at`;
  --> 0.02903763700305717s
ALTER TABLE `test_tables` ENGINE=MyISAM COMMENT='Table Comment Test';
  --> 0.022911186999408528s
SET FOREIGN_KEY_CHECKS=1;
  --> 0.003360001996043138s

$ mysql -u root example_database -e 'show create table test_tables\G'

*************************** 1. row ***************************
       Table: test_tables
Create Table: CREATE TABLE `test_tables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `posted_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=COMPACT COMMENT='Table Comment Test'
```

## Usage

```
Commands:
  convergence apply FILE -c, --config=CONFIG   # execute sql to your database
                                                # [--dry-run], [--rollback-dry-run], [--safe-migration], [--ignore-auto-increment]
  convergence diff FILE1 FILE2                 # print diff of DSLs
  convergence export -c, --config=CONFIG       # export db schema to dsl
                                                # [--dump-rails-migration], [--filename=FILENAME]
  convergence help [COMMAND]                   # Describe available commands or one specific command
  convergence version                          # print the version
```

### DB Config

You need to make database.yml to access your database.

```
$ cat database.yml
adapter: mysql
database: convergence_test
host: 127.0.0.1
username: root
password:
```

To use PostgreSQL instead, set `adapter: postgresql` (`postgres`/`pg` also work):

```
$ cat database.yml
adapter: postgresql
database: convergence_test
host: 127.0.0.1
username: postgres
password:
```

#### PostgreSQL notes

The Convergence DSL uses MySQL terminology for column types (`tinyint`, `mediumint`, `datetime`, ...) so the
same schema files stay close to portable across adapters; the PostgreSQL adapter maps them to their closest
native PostgreSQL type (e.g. `mediumint`/`int` → `integer`, `datetime` → `timestamp`, `json` → `jsonb`,
`extra: 'auto_increment'` → `GENERATED BY DEFAULT AS IDENTITY`, requiring PostgreSQL 10+).

A few MySQL-specific concepts have no PostgreSQL equivalent and are ignored on that adapter: `engine`,
`row_format`, `default_charset`/`character_set`, and `collate`. `enum`/`set` column types are not supported yet
on PostgreSQL.

To use SQLite instead, set `adapter: sqlite3` (`sqlite` also works) and point `database` at a file path:

```
$ cat database.yml
adapter: sqlite3
database: /path/to/development.sqlite3
```

#### SQLite notes

SQLite's `ALTER TABLE` support is intentionally limited by SQLite itself: it can only add/drop columns and
create/drop indexes on an existing table. Changing a column's type/null/default, and adding or removing a
foreign key or primary key on an existing table, all require SQLite's own "rebuild the table" procedure
(create a new table, copy the data over, drop the old one, rename it), which this adapter does not implement
yet -- it raises `NotImplementedError` instead of generating SQL that SQLite would reject. Creating a brand new
table with any of the above (including foreign keys) works fine. Renaming a table/column via `renamed_from:`
(see [Rename tables and columns](#rename-tables-and-columns)) is an exception to this limitation -- SQLite has
natively supported `RENAME TABLE`/`RENAME COLUMN` since 3.25.0, so it doesn't need the rebuild procedure.

Like PostgreSQL, MySQL-only table options (`engine`, `row_format`, `default_charset`/`character_set`, `collate`,
table/column `comment`) have no SQLite equivalent and are ignored. `extra: 'auto_increment'` maps to SQLite's
`INTEGER PRIMARY KEY AUTOINCREMENT`.

#### Use SSL connection

If you would like to use SSL connection, you can specify SSL options in database.yml

```
$ cat database.yml
adapter: mysql
database: convergence_test
host: 127.0.0.1
username: root
password:
sslca: /path/to/ca-cert.pem
sslverify: true
```

Supported ssl options are below:
* `ssl_mode`
* `sslkey`
* `sslcert`
* `sslca`
* `sslcapath`
* `sslcipher`
* `sslverify`

See [the ssl options section of mysql2 README](https://github.com/brianmario/mysql2/tree/master#ssl-options) for more details of SSL options

### Export Your DB Schema

First, you need to create database.yml.
And then, execute command like below.

```
$ convergence export -c database.yml > example.schema
```

Export DSL like this.

```
create_table "authors", collate: "utf8_general_ci" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "name", limit: 110
  t.datetime "created_at", null: true
  t.datetime "updated_at", null: true

  t.index "created_at", name: "index_authors_on_created_at"
end

create_table "papers", collate: "utf8_general_ci", comment: "Paper" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "title1", limit: 300, comment: "Title 1"
  t.varchar "title2", limit: 300, comment: "Title 2"
  t.text "description", null: true, comment: "Description"
end

create_table "paper_authors", collate: "utf8_general_ci", comment: "Paper Author Relation" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.int "paper_id", comment: "Paper id"
  t.int "author_id", comment: "Paper author id"

  t.foreign_key "author_id", reference: "authors", reference_column: "id", name: "paper_authors_author_id_fk"
  t.foreign_key "paper_id", reference: "papers", reference_column: "id", name: "paper_authors_paper_id_fk"
end
```

### Export as a Rails migration file

If you're migrating to (or working alongside) a Rails app, pass `--dump-rails-migration` to export the schema as an
ActiveRecord migration instead of a Convergence DSL file. `--filename` sets the base filename/class name (Rails'
usual `snake_case` filename / `CamelCase` class name convention applies).

```
$ convergence export -c database.yml --dump-rails-migration --filename create_initial_tables
```

```ruby
# Filename: 20240101000000_create_initial_tables.rb
class CreateInitialTables < ActiveRecord::Migration[7.0]
  def change
    create_table :authors do |t|
      t.string :name, limit: 110
      t.timestamps

      t.index :created_at, name: "index_authors_on_created_at"
    end
  end
end
```

The output is written to stdout with a `# Filename: ...` comment on top (including a timestamp prefix in the usual
Rails migration filename format) — redirect it to that file yourself, e.g.
`convergence export ... > db/migrate/$(date +%Y%m%d%H%M%S)_create_initial_tables.rb`.

A few notes on the conversion:
* An `id` column that matches Rails' implicit auto-incrementing primary key (`int`/`bigint`, `primary_key: true`,
  `extra: 'auto_increment'`) is omitted, since `create_table` adds it automatically.
* `created_at`/`updated_at` columns with matching `datetime`/`null` options are collapsed into `t.timestamps`.
* Column types use Rails' type names (e.g. `varchar` → `string`, `datetime`/`timestamp` → `datetime`); `enum`/`set`
  have no ActiveRecord equivalent and fall back to `string`.
* MySQL-only concepts with no `create_table` DSL equivalent (`character_set`, `collate`, `extra`, `after`) are
  dropped from column definitions.

### Dry run

```
$ convergence apply example.schema -c database.yml --dry-run
```

### Rollback Dry run

```
$ convergence apply example.schema -c database.yml --rollback-dry-run
```


### Apply

```
$ convergence apply example.schema -c database.yml
```

### Ignore AUTO_INCREMENT changes

If you dump your schema from a database with a high AUTO_INCREMENT value (e.g. a dev/staging box you've been testing on)
and apply it to another database, convergence will normally generate a query that bumps AUTO_INCREMENT to match, which
can jump/skip a large range of ids. Pass `--ignore-auto-increment` to skip generating AUTO_INCREMENT change queries entirely.

```
$ convergence apply example.schema -c database.yml --ignore-auto-increment
```

This also applies to `--dry-run` and `--rollback-dry-run`.

### Safe migration

If you want to prevent convergence from ever dropping a table (e.g. when the DSL file removed a table that still
has important data), pass `--safe-migration`. It skips generating `DROP TABLE` queries; every other change is still applied.

```
$ convergence apply example.schema -c database.yml --safe-migration
```

This also applies to `--dry-run` and `--rollback-dry-run`.

### Rename tables and columns

Without `renamed_from:`, convergence detects a renamed table/column as a drop followed by an add -- which loses
the data in that table/column. Add `renamed_from:` to the new name so convergence generates `RENAME TABLE`/`RENAME
COLUMN` instead:

```ruby
create_table "user_accounts", renamed_from: "users" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "full_name", limit: 200, renamed_from: "name"
end
```

A few things to know:

* When a table or column has `renamed_from:`, **only the rename is applied on that pass** -- any other change to
  the same table/column (a type change, a new `null`/`default`, ...) is ignored until you run `apply` again. Run
  `apply` a second time (with `renamed_from:` still in place, or removed) to pick up the rest.
* `renamed_from:` is safe to leave in the schema file after the rename has been applied -- convergence detects
  that the target name already exists and treats it as a no-op.
* Swapping two names (A ↔ B) or chaining renames (A → B → C) in a single `apply` is not supported. Use an
  intermediate temporary name and apply in multiple steps instead.
* MySQL's `RENAME COLUMN` requires MySQL 8.0+; there's no fallback for 5.7.
* `convergence diff`'s pretty-printed output does not yet understand renames -- it will describe a rename as "no
  change" for the renamed table/column. This is a known limitation, unrelated to the SQL that `apply`/`dry-run`
  actually generate.

### Include Other Schema files

```
include 'first_schema.schema'
include 'other_file.schema'
```

### Execute raw SQL

For things the DSL has no dedicated syntax for (views, triggers, stored procedures, data backfills, grants, ...),
use `execute` to run an arbitrary SQL statement. Unlike `create_table`, statements passed to `execute` are **not**
diffed against the current schema: they run every time the schema file is applied, so make sure the SQL itself is
idempotent (e.g. `CREATE OR REPLACE VIEW ...`, `CREATE TABLE IF NOT EXISTS ...`).

```
execute "CREATE OR REPLACE VIEW active_users AS SELECT * FROM users WHERE active = 1"
```

`execute` statements always run after the generated schema changes, and are skipped by `--rollback-dry-run` (there's
no way to know how to reverse an arbitrary SQL statement).


## Detail About Convergence DSL

### support column types

Convergence is currently support column types below.

- tinyint
- smallint
- mediumint
- int
- bigint
- float
- double
- decimal
- char
- varchar
- tinyblob
- blob
- mediumblob
- longblob
- tinytext
- text
- mediumtext
- longtext
- date
- time
- datetime
- timestamp
- year
- json
- enum
- set

```
create_table "tests", comment: 'Column type example' do |t|
  t.int 'id', primary_key: true, extra: 'auto_increment'
  t.float 'float_col', comment: 'Float column'
  t.decimal 'decimal_col', default: "0.000", precision: 12, scale: 3
  t.varchar 'test_string', null: true, default: 'hello', limit: 300
  t.text 'text_col'
  t.datetime 'created_at'
  t.enum 'status', values: %w(active inactive pending), default: 'active'
  t.set 'flags', values: %w(a b c)
end
```

### index

```
create_table "tests", comment: 'Index example' do |t|
  t.int 'id', primary_key: true, extra: 'auto_increment'
  t.varchar 'column1'
  t.varchar 'column2'

  t.index 'column1'
  t.index ['column2', 'column1']
  t.index 'column2', name: 'column2_idx'
end
```

### foreign key

```
create_table "authors" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "name", limit: 110
end

create_table "papers", collate: "utf8_general_ci", comment: "Paper" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "title1"
end

create_table "paper_authors", collate: "utf8_general_ci", comment: "Paper Author Relation" do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.int "paper_id", comment: "Paper id"
  t.int "author_id", comment: "Paper author id"

  t.foreign_key "author_id", reference: "authors", reference_column: "id"
  t.foreign_key "paper_id", reference: "papers", reference_column: "id", name: "paper_authors_paper_id_fk"
end

```

### table options

```
create_table "authors", comment: 'Author', engine: 'MyISAM', collate: "utf8_general_ci", default_charset: 'utf8' do |t|
  t.int "id", primary_key: true, extra: "auto_increment"
  t.varchar "name", limit: 110
end
```

### auto increment

```
create_table "orders", auto_increment: 1000 do |t|
  t.int :id, primary_key: true, extra: :auto_increment
end
```

## Test

```
$ bundle exec rake db:convergence:prepare
$ bundle exec rake db:convergence:postgres:prepare
$ bundle exec rake db:convergence:sqlite:prepare
$ bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to set up a
development environment, run the test suite, and what to include in a pull request.

## Copyright

Copyright © 2014-2018 S.nishio. See LICENSE.txt for further details.
