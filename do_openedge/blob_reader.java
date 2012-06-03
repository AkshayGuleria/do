//Blob Reader
import java.sql.*;
import java.io.*;
import java.util.*;

public class rxblob {
    static DataInputStream kbd = new DataInputStream(System.in);
    static String url = "jdbc:jdbcprogress:T:localhost:3002:sports2000";
    static String driver = "com.progress.sql.jdbc.JdbcProgressDriver";
    static String login = "me";
    static String passwd = "x";
    static String filename = "./yahoocopy.gif";
    static String tablename = "";
    static String blobcolumnname = "";
    static String selectcolumnname = "";
    static String selectcolumnvalue = "";
    static Connection curConn = null;

    public static void main(String argv[]) throws IOException    {
        String temp = "";
        rxblob session = new rxblob();
    }

    public rxblob() throws IOException {
        try   {
            Class.forName(driver);
            curConn = DriverManager.getConnection(url, login, passwd);
        }  catch (java.lang.Exception ex) {
            ex.printStackTrace();
            return;
        }
        processBlob();
        finalize();
    }

    protected void finalize() {
        try {
            curConn.close();
        }  catch (SQLException ex) {
        }
    }

    private void processBlob() throws IOException {
        try {
            File blobFile = new File(filename);
            OutputStream fblob = new FileOutputStream(blobFile);
            Statement myStatement = curConn.createStatement();
            ResultSet rs = myStatement.executeQuery("SELECT * from lonvarbin");

            // we retrieve in 4K chunks
            byte[] buffer = new byte[5103];

            InputStream strim = null;
            BufferedInputStream s = null;
            int size = 0;

            try {
                // fetch blob
                if (rs.next()) strim = rs.getBinaryStream(2);
            } catch (SQLException e) {
                e.printStackTrace();
            }

            //new Line!
            if (strim != null) {
                s = new BufferedInputStream(strim);
                while(size != -1) {
                    size = s.read(buffer);
                    System.out.println(size);
                    if (size == 0) break;
                }
                try {
                    System.out.println(buffer.length);
                    System.out.println(buffer[0]);
                    System.out.println(buffer[1]);
                    System.out.println(buffer[2]);
                    System.out.println.(buffer[3]);
                    System.out.println(buffer[buffer.length/2]);
                    System.out.println(buffer[buffer.length/2 - 1]);
                    System.out.println(buffer[buffer.length - 1]);
                    fblob.write(buffer);
                    fblob.flush();
                    fblob.close();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            } else System.out.println("Row not found.");
        } catch (Exception ex) {
            ex.printStackTrace ();
        }
    }
}