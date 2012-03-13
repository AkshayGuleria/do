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
CONFIG.uri = "jdbc:openedge://Abe@192.168.1.245:13370/test2012"

module DataObjectsSpecHelpers

  TABLE_NOT_FOUND_CODE = -20005
  SEQUENCE_NOT_FOUND_CODE = -210051
  SEQUENCE_NOT_VALID_CODE = -20170
  TRIGGER_NOT_FOUND_CODE = -20147

  def drop_table_seq_and_trig(conn, table_name, catalog="pub")
    table_name = "#{catalog}.#{table_name}" if catalog && !catalog.empty?
    begin
      conn.create_command("DROP TABLE #{table_name}").execute_non_query
    rescue DataObjects::SQLError => e
      # OpenEdge does not support DROP TABLE IF EXISTS
      raise e unless e.code == TABLE_NOT_FOUND_CODE
    end

    begin
      conn.create_command("DROP SEQUENCE #{table_name}_seq").execute_non_query
    rescue DataObjects::SQLError => e
      raise e unless [SEQUENCE_NOT_FOUND_CODE, SEQUENCE_NOT_VALID_CODE].include?(e.code)
    end

    begin
      conn.create_command("DROP TRIGGER #{table_name}_trigger").execute_non_query
    rescue DataObjects::SQLError => e
      raise e unless e.code == TRIGGER_NOT_FOUND_CODE
    end
  end

  def create_seq_and_trigger(conn, table_name, catalog="pub")
    table_name = "#{catalog}.#{table_name}" if catalog && !catalog.empty?
    conn.create_command(<<-EOF).execute_non_query
      CREATE SEQUENCE #{table_name}_seq
      START WITH 0,
      INCREMENT BY 1,
      NOCYCLE
    EOF

    if catalog && !catalog.empty?
      # Not totally clear why this is necessary, but it works
      # Solution taken from ProKB P131308
      conn.create_command(<<-EOF).execute_non_query
        GRANT UPDATE ON SEQUENCE #{table_name}_seq TO #{catalog.upcase}
      EOF
    end

    conn.create_command(<<-EOF).execute_non_query
      CREATE TRIGGER #{table_name}_trigger
      BEFORE INSERT ON #{table_name}
      REFERENCING NEWROW
      FOR EACH ROW
      IMPORT
      import java.sql.*;
      BEGIN
      Integer current_id = (Integer)NEWROW.getValue(1, INTEGER);
      if (current_id == -1) {
        SQLCursor next_id_query = new SQLCursor("SELECT TOP 1 #{table_name}_seq.NEXTVAL FROM SYSPROGRESS.SYSCALCTABLE");
        next_id_query.open();
        next_id_query.fetch();
        Integer next_id = (Integer)next_id_query.getValue(1,INTEGER);
        next_id_query.close();
        NEWROW.setValue(1, next_id);
      }
      END
    EOF
  end

  def setup_test_environment
    conn = DataObjects::Connection.new(CONFIG.uri)

    drop_table_seq_and_trig(conn, "invoices")
    drop_table_seq_and_trig(conn, "users")
    drop_table_seq_and_trig(conn, "widgets")

    # Users
    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE pub.users (
        id                INTEGER PRIMARY KEY DEFAULT -1,
        name              VARCHAR(200) default 'Billy',
        fired_at          TIMESTAMP
      )
    EOF
    create_seq_and_trigger(conn, "users")

    # Invoices
    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE pub.invoices (
        id                INTEGER PRIMARY KEY DEFAULT -1,
        invoice_number    VARCHAR(50) NOT NULL
      )
    EOF
    create_seq_and_trigger(conn, "invoices")

    # Widgets
    # TODO add image_data, ad_image, and cad_drawing back in
    conn.create_command(<<-EOF).execute_non_query
      CREATE TABLE pub.widgets (
        id                INTEGER PRIMARY KEY DEFAULT -1,
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
    create_seq_and_trigger(conn, "widgets")

    # XXX: OpenEdge has no ENUM
    # status` enum('active','out of stock') NOT NULL default 'active'

    1.upto(16) do |n|
      conn.create_command(<<-EOF).execute_non_query
         INSERT INTO widgets(
          code,
          name,
          shelf_location,
          description,
          ad_description,
          whitepaper_text,
          super_number,
          weight)
        VALUES (
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
