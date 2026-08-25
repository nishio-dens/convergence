# Contributing to Convergence

Thanks for considering a contribution! This document covers everything you need to get a development
environment running, test your change, and open a pull request.

## Development setup

Convergence supports MySQL, PostgreSQL, and SQLite, so the test suite exercises all three. You don't need
every adapter running to work on a change that's scoped to one of them, but `rake spec` runs the whole suite
regardless of which adapter you touched.

1. Install Ruby (see `required_ruby_version` in `convergence.gemspec` for the minimum version) and Bundler.
2. Install dependencies:

   ```
   $ bundle install
   ```

   `sqlite3`, `mysql2`, and `pg` are native extensions; if a gem fails to build, make sure the corresponding
   client library/headers are installed for your OS (e.g. `libmysqlclient-dev`, `libpq-dev`, `libsqlite3-dev`
   on Debian/Ubuntu, or the Homebrew equivalents on macOS).
3. Start MySQL and PostgreSQL (locally, in Docker, however you prefer) and set connection details for all
   three adapters in `spec/config/spec_database.yml` if the defaults don't match your setup.
4. Prepare the test databases:

   ```
   $ bundle exec rake db:convergence:prepare           # MySQL
   $ bundle exec rake db:convergence:postgres:prepare  # PostgreSQL
   $ bundle exec rake db:convergence:sqlite:prepare     # SQLite (no server needed, just a file)
   ```

## Running the tests

```
$ bundle exec rspec
```

or, equivalently:

```
$ bundle exec rake spec
```

If you change the schema of the shared test fixtures (`spec/fixtures/test_db.sql`,
`spec/fixtures/postgres_test_db.sql`, `spec/fixtures/sqlite_test_db.sql`), rebuild the affected database with
the corresponding `overhaul` task (e.g. `rake db:convergence:overhaul`) before rerunning the suite.

## Code style

The project uses RuboCop (see `.rubocop.yml` for the enabled/disabled cops); there's no dedicated Rake task
wired up, so run it directly if you want to check your changes:

```
$ bundle exec rubocop
```

## Adding support for a new adapter capability

Convergence's DSL uses MySQL terminology for column types so that schema files stay close to portable across
adapters. If you're adding a feature to an existing adapter (or a new adapter entirely), the adapter-specific
logic lives in four places per adapter:

- `lib/convergence/database_connector/*_connector.rb` — opens the DB connection.
- `lib/convergence/dumper/*_schema_dumper.rb` — reads the current schema from the database.
- `lib/convergence/sql_generator/*_generator.rb` — turns a diff into `CREATE`/`ALTER`/`DROP` SQL.
- `lib/convergence/default_parameter/*_default_parameter.rb` — fills in / strips adapter-specific defaults
  (e.g. MySQL's default charset) so diffing doesn't produce spurious noise.

All four are dispatched by adapter name in `lib/convergence/database_connector.rb`, `lib/convergence/command.rb`,
`lib/convergence/command/apply.rb`, and `lib/convergence/default_parameter.rb` respectively — a new adapter
needs a `when` branch added to each. Add a parallel fixture database/schema files under `spec/fixtures/` and a
matching test suite (see the existing `spec/postgres_integrations/` or `spec/sqlite_integrations/` for the
pattern) so the new adapter is covered end-to-end.

## Opening a pull request

- Keep pull requests focused on a single change; it makes review (and `CHANGELOG.md`/release notes) easier.
- Add or update specs for any behavior change.
- Update `README.md` if you're adding a user-facing option or adapter capability.
- Reference the issue you're addressing (e.g. `Closes #123`) in the pull request description.
