# Convergence

Convergence is a Database Schema management tools.
Currently, This tools is support only MySQL.

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

## Usage

```
Usage: convergence [options]
    -v, --version
    -c, --config       Database Yaml Setting
    -d, --diff         DSL1,DSL2
    -e, --export       export db schema to dsl
    -i, --input        Input DSL
        --dryrun
        --apply        execute sql to your database
    -h, --help         Display this help message.
```
