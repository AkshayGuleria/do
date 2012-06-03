require 'java'
require 'openedge.jar'
require 'pool.jar'

import 'com.ddtek.jdbc.openedge.OpenEdgeDriver'

conn_str = "jdbc:datadirect:openedge://192.168.1.243:13370;databaseName=test2012;user=Abe"
conn = java.sql.DriverManager.getConnection(conn_str)

rs = conn.createStatement.executeQuery("SELECT * FROM PUB.USERS")
rsm = rs.getMetaData

1.upto(rsm.getColumnCount) do |i|
  puts "#{rsm.getColumnName(i)}: #{rsm.getColumnTypeName(i)} --> #{rsm.getColumnClassName(i)}"
end