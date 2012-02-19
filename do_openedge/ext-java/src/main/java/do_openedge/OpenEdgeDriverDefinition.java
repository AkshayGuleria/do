package do_openedge;

/*
import java.io.IOException;
import java.io.InputStream;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.jruby.Ruby;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.util.ByteList;
*/
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Properties;

import org.jruby.runtime.builtin.IRubyObject;

import data_objects.RubyType;
import data_objects.drivers.AbstractDriverDefinition;

public class OpenEdgeDriverDefinition extends AbstractDriverDefinition {
    public final static String URI_SCHEME = "openedge";
    // . will be replaced with : in Connection.java before connection
    public final static String JDBC_URI_SCHEME = "datadirect.openedge";
    public final static String RUBY_MODULE_NAME = "Openedge";
    public final static String JDBC_DRIVER = "com.ddtek.jdbc.openedge.OpenEdgeDriver";

    /**
     *
     */
    public OpenEdgeDriverDefinition() {
        //super(URI_SCHEME, RUBY_MODULE_NAME, JDBC_DRIVER);
        super(URI_SCHEME, JDBC_URI_SCHEME, RUBY_MODULE_NAME, JDBC_DRIVER);
    }

    /**
     *
     * @return
     */
    @Override
    public boolean supportsJdbcGeneratedKeys()
    {
        return true;
    }

    /**
     *
     * @return
     */
    @Override
    public boolean supportsJdbcScrollableResultSets() {
        return true;
    }

    /**
     *
     * @return
     */
    @Override
    public Properties getDefaultConnectionProperties() {
        Properties props = new Properties();

        props.put("databaseName", "sports2012");
        props.put("user", "Abe");
        return props;
    }

}
