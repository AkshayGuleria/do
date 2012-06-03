require 'java'
require 'openedge.jar'
require 'pool.jar'

import 'com.ddtek.jdbc.openedge.OpenEdgeDriver'
java_import java.sql.Types

TYPES = ["ARRAY", "BIGINT", "BINARY", "BIT", "BLOB", "BOOLEAN",
         "CHAR", "CLOB", "DATALINK", "DATE", "DECIMAL", "DISTINCT",
         "DOUBLE", "FLOAT", "INTEGER", "JAVA_OBJECT", "LONGVARBINARY",
         "LONGVARCHAR", "NULL", "NUMERIC", "OTHER", "REAL", "REF",
         "SMALLINT", "STRUCT", "TIME", "TIMESTAMP", "TINYINT",
         "VARBINARY", "VARCHAR"]
sql_types = Hash.new
TYPES.each do |t|
  enum = eval("Types::#{t}")
  sql_types[enum] = t
end

COLS = {:TYPE_NAME => "String",
        :DATA_TYPE => "Int",
        :PRECISION => "Int",
        :LITERAL_PREFIX => "String",
        :LITERAL_SUFFIX => "String",
        :CREATE_PARAMS => "String",
        :NULLABLE => "Int",
        :CASE_SENSITIVE => "Boolean",
        :SEARCHABLE => "Int",
        :UNSIGNED_ATTRIBUTE => "Boolean",
        :FIXED_PREC_SCALE => "Boolean",
        :AUTO_INCREMENT => "Boolean",
        :LOCAL_TYPE_NAME => "String",
        :MINIMUM_SCALE => "Int",
        :MAXIMUM_SCALE => "Int",
        :SQL_DATA_TYPE => "Int",
        :SQL_DATETIME_SUB => "Int",
        :NUM_PREC_RADIX => "Int" }.freeze

conn_str = "jdbc:datadirect:openedge://192.168.1.243:13370;databaseName=test2012;user=Abe"
conn = java.sql.DriverManager.getConnection(conn_str)
dbm = conn.getMetaData

rs = dbm.getTypeInfo
while (rs.next)
  type_i = rs.getInt('DATA_TYPE')
  puts "TYPE_NAME: #{rs.getString('TYPE_NAME')}"
  puts "SQL TYPE:  #{sql_types[type_i]}"
  #puts "!! " + rs.getString("TYPE_NAME") + ":" + rs.get + " !!"
  #COLS.each do |k,v|
  #  puts rs.send("get#{v}", k.to_s)
  #end
  puts "***************************************"
end
rs.close
