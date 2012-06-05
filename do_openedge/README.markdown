# do_openedge

* <http://dataobjects.info>

## Description

An OpenEdge driver for DataObjects.

## Features/Problems

This driver implements the DataObjects API for the Progress OpenEdge relational database.
This driver is currently provided only for JRuby.

### Known Issues

#### Version 10.2B

 * DECIMAL/NUMERIC SQL types truncate all digits after the decimal point.
   According to ProKB #P187898, it appears to be a regression bug in the JDBC
   driver. This is causing one of the BigDecimal specs to fail.

## Synopsis

An example of usage:

    @connection = DataObjects::Connection.new("openedge://localhost:4000/sports2000")
    @reader = @connection.create_command('SELECT * FROM State').execute_reader
    @reader.next!

The `Connection` constructor should be passed either a DataObjects-style URI or
JDBC-style URI:

    openedge://user:password@host:port/database?option1=value1&option2=value2
    jdbc:datadirect:openedge://host:port/database?user=<value>&password=<value>

Note that the DataDirect proprietary-style JDBC URI tokenized with `;`s:

    jdbc:datadirect:openedge://host:port;databaseName=database;user=<value>;password=<value>

is *NOT* supported (pull requests accepted).

## Requirements

 * JRuby 1.3.1 + (1.4+ recommended)
 * `data_objects` gem
 * `do_jdbc` gem (shared library)

## Install

To install the gem:

    jruby -S gem install do_openedge

To compile and install from source:

 * Install the Java Development Kit (provided if you are on a recent version of
   Mac OS X) from <http://java.sun.com>
 * Install a recent version of JRuby. Ensure `jruby` is in your `PATH` and/or
   you have configured the `JRUBY_HOME` environment variable to point to your
   JRuby installation.
 * Install `data_objects` and `do_jdbc` with `jruby -S rake install`.
 * Install this driver with `jruby -S rake install`.

## Developers

Follow the above installation instructions. Additionally, you'll need:
  * `rspec` gem for running specs.
  * `YARD` gem for generating documentation.

See the DataObjects wiki for more comprehensive information:
<http://wiki.github.com/datamapper/do/jruby>.

To run specs:

    jruby -S rake spec

To run specs without compiling extensions first:

    jruby -S rake spec_no_compile

To run individual specs:

    jruby -S rake spec SPEC=spec/connection_spec.rb

### Spec data set-up

The specs require an empty database to populate with data to run
tests against.  Here are some commands to be ran from `proenv` to
create the database to be used for testing:

  prodb test empty
  proutil test -C convchar convert utf-8
  sql_env
  proserve test -S 4000 -cpinternal utf-8 -cpstream utf-8

I don't think that the SQL engine is affected by the codepage
settings, but it doesn't hurt to be careful.

## License

This code is licensed under an **MIT (X11) License**. Please see the
accompanying `LICENSE` file.
