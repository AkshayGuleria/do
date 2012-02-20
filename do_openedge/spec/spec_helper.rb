$TESTING=true
JRUBY = true

require 'rubygems'
require 'rspec'
require 'date'
require 'ostruct'
require 'fileutils'

driver_lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(driver_lib) unless $LOAD_PATH.include?(driver_lib)

# Prepend data_objects/do_jdbc in the repository to the load path.
# DO NOT USE installed gems, except when running the specs from gem.
repo_root = File.expand_path('../../..', __FILE__)
['data_objects', 'do_jdbc'].each do |lib|
  lib_path = "#{repo_root}/#{lib}/lib"
  $LOAD_PATH.unshift(lib_path) if File.directory?(lib_path) && !$LOAD_PATH.include?(lib_path)
end

require 'data_objects'
require 'data_objects/spec/setup'
require 'data_objects/spec/lib/pending_helpers'
require 'do_openedge'

DataObjects::Openedge.logger = DataObjects::Logger.new(STDOUT, :off)
at_exit { DataObjects.logger.flush }


CONFIG              = OpenStruct.new
=begin
CONFIG.uri          = ENV["DO_DERBY_SPEC_URI"] || "jdbc:derby:testdb;create=true"
CONFIG.driver       = 'derby'
CONFIG.jdbc_driver  = DataObjects::Derby::JDBC_DRIVER
CONFIG.testsql      = "SELECT 1 FROM SYSIBM.SYSDUMMY1"
=end
CONFIG.uri = "jdbc:openedge://Abe@192.168.1.245:2500/sports2012"

TABLE_NOT_FOUND_CODE = -20005
SEQUENCE_NOT_FOUND_CODE = -210051

module DataObjectsSpecHelpers

  def setup_test_environment
    conn = DataObjects::Connection.new(CONFIG.uri)

    # OpenEdge does not support DROP TABLE IF EXISTS
    begin
      conn.create_command(<<-EOF).execute_non_query
        DROP TABLE invoices
      EOF
    rescue DataObjects::SQLError => e
      raise e unless e.code == TABLE_NOT_FOUND_CODE
    end

    begin
      conn.create_command(<<-EOF).execute_non_query
          DROP TABLE users
      EOF
    rescue DataObjects::SQLError => e
      raise e unless e.code == TABLE_NOT_FOUND_CODE
    end

    begin
      conn.create_command(<<-EOF).execute_non_query
          DROP SEQUENCE pub.users_sequence
      EOF
    rescue DataObjects::SQLError => e
      raise e unless e.code == SEQUENCE_NOT_FOUND_CODE
    end

    begin
      conn.create_command(<<-EOF).execute_non_query
        DROP TABLE widgets
      EOF
    rescue DataObjects::SQLError => e
      raise e unless e.code == TABLE_NOT_FOUND_CODE
    end

    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE users (
        id                INTEGER PRIMARY KEY,
        name              VARCHAR(200) default 'Billy',
        fired_at          TIMESTAMP
      )
    EOF

    conn.create_command(<<-EOF).execute_non_query
      CREATE SEQUENCE pub.users_sequence
        START WITH 1,
        INCREMENT BY 1,
        NOCYCLE
    EOF


    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE invoices (
        id                INTEGER PRIMARY KEY,
        invoice_number    VARCHAR(50) NOT NULL
      )
    EOF

    # TODO add image_data, ad_image, and cad_drawing back in
    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE widgets (
        id                INTEGER PRIMARY KEY,
        code              CHAR(8) DEFAULT 'A14',
        name              VARCHAR(200) DEFAULT 'Super Widget',
        shelf_location    VARCHAR(50),
        description       LVARCHAR,
        ad_description    LVARCHAR,
        whitepaper_text   LVARCHAR,
        flags             BIT DEFAULT 0,
        number_in_stock   SMALLINT DEFAULT 500,
        number_sold       INTEGER DEFAULT 0,
        super_number      BIGINT DEFAULT 9223372036854775807,
        weight            FLOAT DEFAULT 1.23,
        cost1             REAL DEFAULT 10.23,
        cost2             DECIMAL DEFAULT 50.23,
        release_date      DATE DEFAULT '2008-02-14',
        release_datetime  TIMESTAMP DEFAULT '2008-02-14 00:31:12',
        release_timestamp TIMESTAMP DEFAULT '2008-02-14 00:31:31'
      )
    EOF

    # XXX: OpenEdge has no ENUM
    # status` enum('active','out of stock') NOT NULL default 'active'

    1.upto(16) do |n|
      conn.create_command(<<-EOF).execute_non_query
         INSERT INTO widgets(
          id,
          code,
          name,
          shelf_location,
          description,
          ad_description,
          whitepaper_text,
          super_number,
          weight)
        VALUES (
          #{n},
          'W#{n.to_s.rjust(7,"0")}',
          'Widget #{n}',
          'A14',
          'This is a description',
          'Buy this product now!',
          'String',
          1234,
          13.4)
      EOF
    end

    conn.create_command(<<-EOF).execute_non_query
      update widgets set flags = 1 where id = 2
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set ad_description = NULL where id = 3
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set flags = NULL where id = 4
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set cost1 = NULL where id = 5
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set cost2 = NULL where id = 6
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set release_date = NULL where id = 7
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set release_datetime = NULL where id = 8
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set release_timestamp = NULL where id = 9
    EOF

    conn.create_command(<<-EOF).execute_non_query
      update widgets set release_datetime = '2008-07-14 00:31:12' where id = 10
    EOF

    conn.close
  end
end

RSpec.configure do |config|
  config.include(DataObjectsSpecHelpers)
  config.include(DataObjects::Spec::PendingHelpers)
end
