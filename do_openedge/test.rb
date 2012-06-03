require 'rubygems'
require 'data_objects'
require 'do_openedge'

CONN_URI = "jdbc:openedge://Abe@192.168.1.243:13370/test2012;databaseName=test2012;user=Abe"
conn = DataObjects::Connection.new(CONN_URI)

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
    Long current_id = (Long)NEWROW.getValue(1, BIGINT);
    if (current_id == -1) {
      SQLCursor next_id_query = new SQLCursor("SELECT TOP 1 #{table_name}_seq.NEXTVAL FROM SYSPROGRESS.SYSCALCTABLE");
      next_id_query.open();
      next_id_query.fetch();
      Long next_id = (Long)next_id_query.getValue(1,BIGINT);
      next_id_query.close();
      NEWROW.setValue(1, next_id);
    }
    END
  EOF
end

drop_table_seq_and_trig(conn, "invoices")
drop_table_seq_and_trig(conn, "users")
drop_table_seq_and_trig(conn, "widgets")

# Users
conn.create_command(<<-EOF).execute_non_query
  CREATE TABLE users (
    id                BIGINT PRIMARY KEY DEFAULT -1,
    name              VARCHAR(200) default 'Billy',
    fired_at          TIMESTAMP
  )
EOF
create_seq_and_trigger(conn, "users", "")

# Invoices
conn.create_command(<<-EOF).execute_non_query
  CREATE TABLE invoices (
    id                BIGINT PRIMARY KEY DEFAULT -1,
    invoice_number    VARCHAR(50) NOT NULL
  )
EOF
create_seq_and_trigger(conn, "invoices", "")

# Widgets
conn.create_command(<<-EOF).execute_non_query
  CREATE TABLE widgets (
    id                BIGINT PRIMARY KEY DEFAULT -1,
    code              CHAR(8) DEFAULT 'A14',
    name              VARCHAR(200) DEFAULT 'Super Widget',
    shelf_location    VARCHAR(4000),
    description       VARCHAR(4000),
    image_data        BLOB,
    ad_description    VARCHAR(4000),
    ad_image          BLOB,
    whitepaper_text   CLOB,
    class_name        VARCHAR(4000),
    cad_drawing       BLOB,
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
create_seq_and_trigger(conn, "widgets", "")

# XXX: OpenEdge has no ENUM
# status` enum('active','out of stock') NOT NULL default 'active'

command = conn.create_command(<<-EOF)
  INSERT INTO widgets(
    code,
    name,
    shelf_location,
    description,
    ad_description,
    super_number,
    weight)
  VALUES (?, ?, ?, ?, ?, ?, ?)
EOF

1.upto(16) do |n|
  command.execute_non_query(
    "W#{n.to_s.rjust(7,'0')}",
    "Widget #{n}",
    'A14',
    'This is a description',
    'Buy this product now!',
    1234,
    13.4)
end



# TOREMOVE below here
r = conn.create_command(<<-EOF).execute_reader
  SELECT * FROM widgets
EOF

1.upto(15) do |n|
  conn.create_command("INSERT INTO users(name) VALUES('#{n.to_s}')").execute_non_query
end