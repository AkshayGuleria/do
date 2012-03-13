package do_openedge;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Properties;
import java.net.URI;

import org.jruby.runtime.builtin.IRubyObject;

import data_objects.RubyType;
import data_objects.drivers.AbstractDriverDefinition;

public class OpenEdgeDriverDefinition extends AbstractDriverDefinition {

    public final static String URI_SCHEME = "openedge";
    // . in JDBC_URI_SCHEME will be replaced with : in Connection.java before connection
    public final static String JDBC_URI_SCHEME = "datadirect.openedge";
    public final static String RUBY_MODULE_NAME = "Openedge";
    public final static String JDBC_DRIVER = "com.ddtek.jdbc.openedge.OpenEdgeDriver";

    /**
     *
     */
    public OpenEdgeDriverDefinition() {
        super(URI_SCHEME, JDBC_URI_SCHEME, RUBY_MODULE_NAME, JDBC_DRIVER);
    }

    /**
     *
     * Verified by checking that
     * conn.getMetaData().supportsGetGeneratedKeys() == false
     * and confirmed experimentally - when calling conn.prepareStatement with
     * Statement.RETURN_GENERATED_KEYS, an error is thrown:
     * java.sql.SQLFeatureNotSupportedException
     *
     * @return
     */
    @Override
    public boolean supportsJdbcGeneratedKeys()
    {
        return false;
    }

    /**
     *
     * Verified by successfully calling conn.prepareStatement with
     * Statement.NO_GENERATED_KEYS
     *
     * @return
     */
    public boolean supportsConnectionPrepareStatementMethodWithGKFlag() {
        return true;
    }

    /**
     *
     * TODO - see how Oracle driver does this w/ its sequences
     *
     * @param connection
     * @return
     */
    @Override
    public ResultSet getGeneratedKeys(Connection connection) {
        return null;
    }


    /**
     *
     * Verified by creating a statement with ResultSet.TYPE_SCROLL_INSENSITIVE
     * and successfully scrolling forward (rs.next()) *and backward* (rs.previous())!
     *
     * @return
     */
    @Override
    public boolean supportsJdbcScrollableResultSets() {
        return true;
    }

    /**
     *
     * TODO
     *
     * @return
     */
    @Override
    public Properties getDefaultConnectionProperties() {
        Properties props = new Properties();

        props.put("databaseName", "test2012");
        props.put("user", "Abe");
        return props;
    }

    /**
     *
     * TODO
     *
     * @param connectionUri
     * @return
     */
    @Override
    public String getJdbcUri(URI connectionUri) {
      String jdbcUri = connectionUri.toString();
      System.out.println("JDBC STARTING URI IS " + jdbcUri);

      // Replace . with : in scheme name - necessary for OpenEdge scheme datadirect:openedge
      // : cannot be used in JDBC_URI_SCHEME as then it is identified as opaque URI
      jdbcUri = jdbcUri.replaceFirst("^([a-z]+)(\\.)", "$1:");

      if (!jdbcUri.startsWith("jdbc:")) {
          jdbcUri = "jdbc:" + jdbcUri;
      }
      return jdbcUri;
    }

}
