package data_objects.drivers;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URI;
import java.net.URISyntaxException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Map;
import java.util.Properties;

import org.jruby.Ruby;
import org.jruby.RubyObjectAdapter;
import org.jruby.runtime.builtin.IRubyObject;

import data_objects.RubyType;

/**
 *
 * @author alexbcoles
 */
public interface DriverDefinition {

    /**
     *
     * @return
     */
    public String getModuleName();

    /**
     *
     * @param uri
     * @return
     * @throws URISyntaxException
     * @throws UnsupportedEncodingException
     */
    public URI parseConnectionURI(IRubyObject uri) throws URISyntaxException,
            UnsupportedEncodingException;

    /**
     *
     * @return
     */
    public RubyObjectAdapter getObjectAdapter();

    /**
     * If needed this could be overrided to implement database driver specific
     * JDBC type to Ruby type mapping
     *
     * @param type
     * @param precision
     * @param scale
     * @return
     */
    public RubyType jdbcTypeToRubyType(int type, int precision, int scale);

    /**
     *
     * @param runtime
     * @param rs
     * @param col
     * @param type
     * @return
     * @throws SQLException
     * @throws IOException
     */
    public IRubyObject getTypecastResultSetValue(Ruby runtime, ResultSet rs,
            int col, RubyType type) throws SQLException, IOException;

    /**
     *
     * @param ps
     * @param arg
     * @param idx
     * @throws SQLException
     */
    public void setPreparedStatementParam(PreparedStatement ps,
            IRubyObject arg, int idx) throws SQLException;

    /**
     * Callback for registering output parameter
     * Necessary for Oracle INSERT ... RETURNING ... INTO ... statements
     *
     * @param sqlText
     * @param ps
     * @param idx
     * @throws SQLException
     * @return true if output parameter was registered
     */
    public boolean registerPreparedStatementReturnParam(String sqlText, PreparedStatement ps, int idx) throws SQLException;

    /**
     * Get registered return parameter
     * Necessary for Oracle INSERT ... RETURNING ... INTO ... statements
     *
     * @param ps
     * @throws
     * @return return parameter (long value)
     */
    public long getPreparedStatementReturnParam(PreparedStatement ps) throws SQLException;

    /**
     * Callback for doing driver specific SQL statement modification
     * Necessary for Oracle driver to replace :insert_id with ?
     *
     * @param sqlText
     * @param args
     * @return a SQL Text formatted for preparing a PreparedStatement
     */
    public String prepareSqlTextForPs(String sqlText, IRubyObject[] args);

    /**
     * Whether the Driver supports properly supports JDBC 3.0's
     * autogenerated keys feature
     *
     * @return
     */
    public boolean supportsJdbcGeneratedKeys();

    /**
     * Whether the Driver supports properly JDBC 2.0's
     * scrollable result sets
     *
     * XXX left taking consideration into further versions
     *
     * @return
     */
    public boolean supportsJdbcScrollableResultSets();

    /**
     * A workaround for drivers that throw a SQLException if Connection#prepareStatement(String, int)
     * is called.
     *
     * @return
     */
    public boolean supportsConnectionPrepareStatementMethodWithGKFlag();

    /**
     * Whether the Driver supports specifying a connection encoding
     *
     * @return
     */
    public boolean supportsConnectionEncodings();

    /**
     * If the driver does not properly support JDBC 3.0's autogenerated keys,
     * then custom SQL can be provided to look up the autogenerated keys for
     * a connection.
     *
     * @param connection
     * @return
     */
    public ResultSet getGeneratedKeys(Connection connection);

    /**
     * Same as above, except with extra parameters (needed by the OpenEdge driver)
     *
     * @param connection
     * @param ps
     * @param sqlText
     * @return
     */
    public ResultSet getGeneratedKeys(Connection connection, PreparedStatement ps, String sqlText) throws SQLException;

    /**
     * A default list of properties for a connection for a driver.
     *
     * @return
     */
    public Properties getDefaultConnectionProperties();

    /**
     * Extra properties that should be set based on the connection string.
     *
     * @param connectionUri
     * @return
     */
    public Properties getExtraConnectionProperties(URI connectionUri);

    /**
     * Return database specific JDBC connection string from DataObjects URI
     *
     * @param connectionUri
     * @return
     */
    public String getJdbcUri(URI connectionUri);

    /**
     * Callback for setting connection properties after connection is established.
     *
     * @param doConn
     * @param conn
     * @param query
     * @return
     */
    public void afterConnectionCallback(IRubyObject doConn, Connection conn,
            Map<String, String> query) throws SQLException;

    /**
     * If the driver supports setting connection encodings, specify the appropriate
     * property to set the connection encoding.
     *
     * @param props
     * @param encodingName
     * @see #supportsConnectionEncodings()
     */
    void setEncodingProperty(Properties props, String encodingName);

    /**
     * creates Connection from the given arguments
     *
     * @param uri jdbc uri for which a connection is created
     * @param properties further properties needed to create a cconnection, i.e. username + password
     * @return
     */
    public Connection getConnection(String uri, Properties properties) throws SQLException;

    /**
     *
     * @param runtime
     * @param connection
     * @param url
     * @param props
     * @return
     * @throws SQLException
     * @see java.sql.DriverManager#getConnection
     */
    Connection getConnectionWithEncoding(Ruby runtime, IRubyObject connection,
            String url, Properties props) throws SQLException;

    /**
     *
     * @param str
     * @return
     */
    public String quoteString(String str);

    /**
     *
     * @param connection
     * @param value
     * @return
     */
    public String quoteByteArray(IRubyObject connection, IRubyObject value);

    /**
     *
     * @param s
     * @return
     */
    public String statementToString(Statement s);

}
