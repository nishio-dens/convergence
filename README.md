# Convergence

Convergence is a pure-Ruby database schema migration tool.
Currently, This tool is support only MySQL.

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
  convergence diff FILE1 FILE2                 # print diff of DSLs
  convergence export -c, --config=CONFIG       # export db schema to dsl
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

### Include Other Schema files

```
include 'first_schema.schema'
include 'other_file.schema'
```


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

```
create_table "tests", comment: 'Column type example' do |t|
  t.int 'id', primary_key: true, extra: 'auto_increment'
  t.float 'float_col', comment: 'Float column'
  t.decimal 'decimal_col', default: "0.000", precision: 12, scale: 3
  t.varchar 'test_string', null: true, default: 'hello', limit: 300
  t.text 'text_col'
  t.datetime 'created_at'
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
$ bundle exec rspec
```

## Copyright

Copyright © 2014-2018 S.nishio. See LICENSE.txt for further details.
