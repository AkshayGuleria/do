#include <libpq-fe.h>
#include <postgres.h>
#include <mb/pg_wchar.h>
#include <catalog/pg_type.h>
#include <utils/errcodes.h>

/* Undefine constants Postgres also defines */
#undef PACKAGE_BUGREPORT
#undef PACKAGE_NAME
#undef PACKAGE_STRING
#undef PACKAGE_TARNAME
#undef PACKAGE_VERSION

#ifdef _WIN32
/* On Windows this stuff is also defined by Postgres, but we don't
   want to use Postgres' version actually */
#undef fsync
#undef ftruncate
#undef fseeko
#undef ftello
#undef stat
#undef vsnprintf
#undef snprintf
#undef sprintf
#undef printf
#define cCommand_execute cCommand_execute_sync
#define do_int64 signed __int64
#else
#define cCommand_execute cCommand_execute_async
#define do_int64 signed long long int
#endif

#include <ruby.h>
#include <string.h>
#include <math.h>
#include <ctype.h>
#include <time.h>
#include "error.h"
#include "compat.h"

#include "common.h"

#define DRIVER_CLASS(klass, parent) (rb_define_class_under(mPostgres, klass, parent))

VALUE mPostgres;
VALUE mEncoding;
VALUE cConnection;
VALUE cCommand;
VALUE cResult;
VALUE cReader;

/* ===== Typecasting Functions ===== */

VALUE infer_ruby_type(Oid type) {
  switch(type) {
    case BITOID:
    case VARBITOID:
    case INT2OID:
    case INT4OID:
    case INT8OID:
      return rb_cInteger;
    case FLOAT4OID:
    case FLOAT8OID:
      return rb_cFloat;
    case NUMERICOID:
    case CASHOID:
      return rb_cBigDecimal;
    case BOOLOID:
      return rb_cTrueClass;
    case TIMESTAMPTZOID:
    case TIMESTAMPOID:
      return rb_cDateTime;
    case DATEOID:
      return rb_cDate;
    case BYTEAOID:
      return rb_cByteArray;
    default:
      return rb_cString;
  }
}

VALUE typecast(const char *value, long length, const VALUE type, int encoding) {

#ifdef HAVE_RUBY_ENCODING_H
  rb_encoding *internal_encoding = rb_default_internal_encoding();
#else
  void *internal_encoding = NULL;
#endif

  if (type == rb_cInteger) {
    return rb_cstr2inum(value, 10);
  } else if (type == rb_cString) {
    return DO_STR_NEW(value, length, encoding, internal_encoding);
  } else if (type == rb_cFloat) {
    return rb_float_new(rb_cstr_to_dbl(value, Qfalse));
  } else if (type == rb_cBigDecimal) {
    return rb_funcall(rb_cBigDecimal, ID_NEW, 1, rb_str_new(value, length));
  } else if (type == rb_cDate) {
    return parse_date(value);
  } else if (type == rb_cDateTime) {
    return parse_date_time(value);
  } else if (type == rb_cTime) {
    return parse_time(value);
  } else if (type == rb_cTrueClass) {
    return *value == 't' ? Qtrue : Qfalse;
  } else if (type == rb_cByteArray) {
    size_t new_length = 0;
    char* unescaped = (char *)PQunescapeBytea((unsigned char*)value, &new_length);
    VALUE byte_array = rb_funcall(rb_cByteArray, ID_NEW, 1, rb_str_new(unescaped, new_length));
    PQfreemem(unescaped);
    return byte_array;
  } else if (type == rb_cClass) {
    return rb_funcall(mDO, rb_intern("full_const_get"), 1, rb_str_new(value, length));
  } else if (type == rb_cNilClass) {
    return Qnil;
  } else {
    return DO_STR_NEW(value, length, encoding, internal_encoding);
  }
}

void raise_error(VALUE self, PGresult *result, VALUE query) {
  VALUE exception;
  char *message;
  char *sqlstate;
  int postgres_errno;

  message  = PQresultErrorMessage(result);
  sqlstate = PQresultErrorField(result, PG_DIAG_SQLSTATE);
  postgres_errno = MAKE_SQLSTATE(sqlstate[0], sqlstate[1], sqlstate[2], sqlstate[3], sqlstate[4]);
  PQclear(result);

  const char *exception_type = "SQLError";

  struct errcodes *errs;

  for (errs = errors; errs->error_name; errs++) {
    if(errs->error_no == postgres_errno) {
      exception_type = errs->exception;
      break;
    }
  }

  VALUE uri = rb_funcall(rb_iv_get(self, "@connection"), rb_intern("to_s"), 0);

  exception = rb_funcall(CONST_GET(mDO, exception_type), ID_NEW, 5,
                         rb_str_new2(message),
                         INT2NUM(postgres_errno),
                         rb_str_new2(sqlstate),
                         query,
                         uri);
  rb_exc_raise(exception);
}


/* ====== Public API ======= */

VALUE cConnection_dispose(VALUE self) {
  VALUE connection_container = rb_iv_get(self, "@connection");

  PGconn *db;

  if (Qnil == connection_container)
    return Qfalse;

  db = DATA_PTR(connection_container);

  if (NULL == db)
    return Qfalse;

  PQfinish(db);
  rb_iv_set(self, "@connection", Qnil);

  return Qtrue;
}

VALUE cConnection_quote_string(VALUE self, VALUE string) {
  PGconn *db = DATA_PTR(rb_iv_get(self, "@connection"));

  const char *source = rb_str_ptr_readonly(string);
  size_t source_len  = rb_str_len(string);

  char *escaped;
  size_t quoted_length = 0;
  VALUE result;

  // Allocate space for the escaped version of 'string'
  // http://www.postgresql.org/docs/8.3/static/libpq-exec.html#LIBPQ-EXEC-ESCAPE-STRING
  escaped = (char *)calloc(source_len * 2 + 3, sizeof(char));

  // Escape 'source' using the current charset in use on the conection 'db'
  quoted_length = PQescapeStringConn(db, escaped + 1, source, source_len, NULL);

  // Wrap the escaped string in single-quotes, this is DO's convention
  escaped[quoted_length + 1] = escaped[0] = '\'';

  result = DO_STR_NEW(escaped, quoted_length + 2, FIX2INT(rb_iv_get(self, "@encoding_id")), NULL);

  free(escaped);
  return result;
}

VALUE cConnection_quote_byte_array(VALUE self, VALUE string) {
  PGconn *db = DATA_PTR(rb_iv_get(self, "@connection"));

  const unsigned char *source = (unsigned char*) rb_str_ptr_readonly(string);
  size_t source_len     = rb_str_len(string);

  unsigned char *escaped;
  unsigned char *escaped_quotes;
  size_t quoted_length = 0;
  VALUE result;

  // Allocate space for the escaped version of 'string'
  // http://www.postgresql.org/docs/8.3/static/libpq-exec.html#LIBPQ-EXEC-ESCAPE-STRING
  escaped = PQescapeByteaConn(db, source, source_len, &quoted_length);
  escaped_quotes = (unsigned char *)calloc(quoted_length + 1, sizeof(unsigned char));
  memcpy(escaped_quotes + 1, escaped, quoted_length);

  // Wrap the escaped string in single-quotes, this is DO's convention (replace trailing \0)
  escaped_quotes[quoted_length] = escaped_quotes[0] = '\'';

  result = rb_str_new((const char *)escaped_quotes, quoted_length + 1);
  PQfreemem(escaped);
  free(escaped_quotes);
  return result;
}

void full_connect(VALUE self, PGconn *db);

#ifdef _WIN32
PGresult *cCommand_execute_sync(VALUE self, VALUE connection, PGconn *db, VALUE query) {
  PGresult *response;
  struct timeval start;
  char* str = StringValuePtr(query);

  while ((response = PQgetResult(db)) != NULL) {
    PQclear(response);
  }

  gettimeofday(&start, NULL);

  response = PQexec(db, str);

  if (response == NULL) {
    if(PQstatus(db) != CONNECTION_OK) {
      PQreset(db);
      if (PQstatus(db) == CONNECTION_OK) {
        response = PQexec(db, str);
      } else {
        full_connect(connection, db);
        response = PQexec(db, str);
      }
    }

    if(response == NULL) {
      rb_raise(eConnectionError, PQerrorMessage(db));
    }
  }

  data_objects_debug(connection, query, &start);

  return response;
}
#else
PGresult *cCommand_execute_async(VALUE self, VALUE connection, PGconn *db, VALUE query) {
  int socket_fd;
  int retval;
  fd_set rset;
  PGresult *response;
  struct timeval start;
  char* str = StringValuePtr(query);

  while ((response = PQgetResult(db)) != NULL) {
    PQclear(response);
  }

  gettimeofday(&start, NULL);

  retval = PQsendQuery(db, str);

  if (!retval) {
    if (PQstatus(db) != CONNECTION_OK) {
      PQreset(db);
      if (PQstatus(db) == CONNECTION_OK) {
        retval = PQsendQuery(db, str);
      } else {
        full_connect(connection, db);
        retval = PQsendQuery(db, str);
      }
    }

    if (!retval) {
      rb_raise(eConnectionError, "%s", PQerrorMessage(db));
    }
  }

  socket_fd = PQsocket(db);

  for(;;) {
    FD_ZERO(&rset);
    FD_SET(socket_fd, &rset);
    retval = rb_thread_select(socket_fd + 1, &rset, NULL, NULL, NULL);
    if (retval < 0) {
      rb_sys_fail(0);
    }

    if (retval == 0) {
      continue;
    }

    if (PQconsumeInput(db) == 0) {
      rb_raise(eConnectionError, "%s", PQerrorMessage(db));
    }

    if (PQisBusy(db) == 0) {
      break;
    }
  }

  data_objects_debug(connection, query, &start);

  return PQgetResult(db);
}
#endif

VALUE cConnection_initialize(VALUE self, VALUE uri) {
  VALUE r_host, r_user, r_password, r_path, r_query, r_port;

  PGconn *db = NULL;

  rb_iv_set(self, "@using_socket", Qfalse);

  r_host = rb_funcall(uri, rb_intern("host"), 0);
  if (Qnil != r_host) {
    rb_iv_set(self, "@host", r_host);
  }

  r_user = rb_funcall(uri, rb_intern("user"), 0);
  if (Qnil != r_user) {
    rb_iv_set(self, "@user", r_user);
  }

  r_password = rb_funcall(uri, rb_intern("password"), 0);
  if (Qnil != r_password) {
    rb_iv_set(self, "@password", r_password);
  }

  r_path = rb_funcall(uri, rb_intern("path"), 0);
  if (Qnil != r_path) {
    rb_iv_set(self, "@path", r_path);
  }

  r_port = rb_funcall(uri, rb_intern("port"), 0);
  if (Qnil != r_port) {
    r_port = rb_funcall(r_port, rb_intern("to_s"), 0);
    rb_iv_set(self, "@port", r_port);
  }

  // Pull the querystring off the URI
  r_query = rb_funcall(uri, rb_intern("query"), 0);
  rb_iv_set(self, "@query", r_query);

  const char* encoding = get_uri_option(r_query, "encoding");
  if (!encoding) { encoding = get_uri_option(r_query, "charset"); }
  if (!encoding) { encoding = "UTF-8"; }

  rb_iv_set(self, "@encoding", rb_str_new2(encoding));

  full_connect(self, db);

  rb_iv_set(self, "@uri", uri);

  return Qtrue;
}

void full_connect(VALUE self, PGconn *db) {

  PGresult *result = NULL;
  VALUE r_host, r_user, r_password, r_path, r_port, r_query, r_options;
  char *host = NULL, *user = NULL, *password = NULL, *path = NULL, *database = NULL;
  const char *port = "5432";
  VALUE encoding = Qnil;
  const char *search_path = NULL;
  char *search_path_query = NULL;
  const char *backslash_off = "SET backslash_quote = off";
  const char *standard_strings_on = "SET standard_conforming_strings = on";
  const char *warning_messages = "SET client_min_messages = warning";

  if ((r_host = rb_iv_get(self, "@host")) != Qnil) {
    host = StringValuePtr(r_host);
  }

  if ((r_user = rb_iv_get(self, "@user")) != Qnil) {
    user = StringValuePtr(r_user);
  }

  if ((r_password = rb_iv_get(self, "@password")) != Qnil) {
    password = StringValuePtr(r_password);
  }

  if ((r_port = rb_iv_get(self, "@port")) != Qnil) {
    port = StringValuePtr(r_port);
  }

  if ((r_path = rb_iv_get(self, "@path")) != Qnil) {
    path = StringValuePtr(r_path);
    database = strtok(path, "/");
  }

  if (NULL == database || 0 == strlen(database)) {
    rb_raise(eConnectionError, "Database must be specified");
  }

  r_query = rb_iv_get(self, "@query");

  search_path = get_uri_option(r_query, "search_path");

  db = PQsetdbLogin(
    host,
    port,
    NULL,
    NULL,
    database,
    user,
    password
  );

  if ( PQstatus(db) == CONNECTION_BAD ) {
    rb_raise(eConnectionError, "%s", PQerrorMessage(db));
  }

  if (search_path != NULL) {
    search_path_query = (char *)calloc(256, sizeof(char));
    snprintf(search_path_query, 256, "set search_path to %s;", search_path);
    r_query = rb_str_new2(search_path_query);
    result = cCommand_execute(Qnil, self, db, r_query);

    if (PQresultStatus(result) != PGRES_COMMAND_OK) {
      free((void *)search_path_query);
      raise_error(self, result, r_query);
    }

    free((void *)search_path_query);
  }

  r_options = rb_str_new2(backslash_off);
  result = cCommand_execute(Qnil, self, db, r_options);

  if (PQresultStatus(result) != PGRES_COMMAND_OK) {
    rb_warn("%s", PQresultErrorMessage(result));
  }

  r_options = rb_str_new2(standard_strings_on);
  result = cCommand_execute(Qnil, self, db, r_options);

  if (PQresultStatus(result) != PGRES_COMMAND_OK) {
    rb_warn("%s", PQresultErrorMessage(result));
  }

  r_options = rb_str_new2(warning_messages);
  result = cCommand_execute(Qnil, self, db, r_options);

  if (PQresultStatus(result) != PGRES_COMMAND_OK) {
    rb_warn("%s", PQresultErrorMessage(result));
  }

  encoding = rb_iv_get(self, "@encoding");

#ifdef HAVE_PQSETCLIENTENCODING
  VALUE pg_encoding = rb_hash_aref(CONST_GET(mEncoding, "MAP"), encoding);
  if(pg_encoding != Qnil) {
    if(PQsetClientEncoding(db, rb_str_ptr_readonly(pg_encoding))) {
      rb_raise(eConnectionError, "Couldn't set encoding: %s", rb_str_ptr_readonly(encoding));
    } else {
#ifdef HAVE_RUBY_ENCODING_H
      rb_iv_set(self, "@encoding_id", INT2FIX(rb_enc_find_index(rb_str_ptr_readonly(encoding))));
#endif
      rb_iv_set(self, "@pg_encoding", pg_encoding);
    }
  } else {
    rb_warn("Encoding %s is not a known Ruby encoding for PostgreSQL\n", rb_str_ptr_readonly(encoding));
    rb_iv_set(self, "@encoding", rb_str_new2("UTF-8"));
#ifdef HAVE_RUBY_ENCODING_H
    rb_iv_set(self, "@encoding_id", INT2FIX(rb_enc_find_index("UTF-8")));
#endif
    rb_iv_set(self, "@pg_encoding", rb_str_new2("UTF8"));
  }
#endif
  rb_iv_set(self, "@connection", Data_Wrap_Struct(rb_cObject, 0, 0, db));
}

VALUE cCommand_execute_non_query(int argc, VALUE *argv, VALUE self) {
  VALUE connection = rb_iv_get(self, "@connection");
  VALUE postgres_connection = rb_iv_get(connection, "@connection");
  if (Qnil == postgres_connection) {
    rb_raise(eConnectionError, "This connection has already been closed.");
  }

  PGconn *db = DATA_PTR(postgres_connection);
  PGresult *response;
  int status;

  VALUE affected_rows = Qnil;
  VALUE insert_id = Qnil;

  VALUE query = build_query_from_args(self, argc, argv);

  response = cCommand_execute(self, connection, db, query);

  status = PQresultStatus(response);

  if ( status == PGRES_TUPLES_OK ) {
    if (PQgetlength(response, 0, 0) == 0)  {
      insert_id = Qnil;
    } else {
      insert_id = INT2NUM(atoi(PQgetvalue(response, 0, 0)));
    }
    affected_rows = INT2NUM(atoi(PQcmdTuples(response)));
  }
  else if ( status == PGRES_COMMAND_OK ) {
    insert_id = Qnil;
    affected_rows = INT2NUM(atoi(PQcmdTuples(response)));
  }
  else {
    raise_error(self, response, query);
  }

  PQclear(response);

  return rb_funcall(cResult, ID_NEW, 3, self, affected_rows, insert_id);
}

VALUE cCommand_execute_reader(int argc, VALUE *argv, VALUE self) {
  VALUE reader, query;
  VALUE field_names, field_types;

  int i;
  int field_count;
  int infer_types = 0;

  VALUE connection = rb_iv_get(self, "@connection");
  VALUE postgres_connection = rb_iv_get(connection, "@connection");
  if (Qnil == postgres_connection) {
    rb_raise(eConnectionError, "This connection has already been closed.");
  }

  PGconn *db = DATA_PTR(postgres_connection);
  PGresult *response;

  query = build_query_from_args(self, argc, argv);

  response = cCommand_execute(self, connection, db, query);

  if ( PQresultStatus(response) != PGRES_TUPLES_OK ) {
    raise_error(self, response, query);
  }

  field_count = PQnfields(response);

  reader = rb_funcall(cReader, ID_NEW, 0);
  rb_iv_set(reader, "@connection", connection);
  rb_iv_set(reader, "@reader", Data_Wrap_Struct(rb_cObject, 0, 0, response));
  rb_iv_set(reader, "@opened", Qfalse);
  rb_iv_set(reader, "@field_count", INT2NUM(field_count));
  rb_iv_set(reader, "@row_count", INT2NUM(PQntuples(response)));

  field_names = rb_ary_new();
  field_types = rb_iv_get(self, "@field_types");

  if ( field_types == Qnil || 0 == RARRAY_LEN(field_types) ) {
    field_types = rb_ary_new();
    infer_types = 1;
  } else if (RARRAY_LEN(field_types) != field_count) {
    // Whoops...  wrong number of types passed to set_types.  Close the reader and raise
    // and error
    rb_funcall(reader, rb_intern("close"), 0);
    rb_raise(rb_eArgError, "Field-count mismatch. Expected %ld fields, but the query yielded %d", RARRAY_LEN(field_types), field_count);
  }

  for ( i = 0; i < field_count; i++ ) {
    rb_ary_push(field_names, rb_str_new2(PQfname(response, i)));
    if ( infer_types == 1 ) {
      rb_ary_push(field_types, infer_ruby_type(PQftype(response, i)));
    }
  }

  rb_iv_set(reader, "@position", INT2NUM(0));
  rb_iv_set(reader, "@fields", field_names);
  rb_iv_set(reader, "@field_types", field_types);

  return reader;
}

VALUE cReader_close(VALUE self) {
  VALUE reader_container = rb_iv_get(self, "@reader");

  PGresult *reader;

  if (Qnil == reader_container)
    return Qfalse;

  reader = DATA_PTR(reader_container);

  if (NULL == reader)
    return Qfalse;

  PQclear(reader);
  rb_iv_set(self, "@reader", Qnil);
  rb_iv_set(self, "@opened", Qfalse);

  return Qtrue;
}

VALUE cReader_next(VALUE self) {
  PGresult *reader = DATA_PTR(rb_iv_get(self, "@reader"));

  int field_count;
  int row_count;
  int i;
  int position;

  VALUE array = rb_ary_new();
  VALUE field_types, field_type;
  VALUE value;

  row_count = NUM2INT(rb_iv_get(self, "@row_count"));
  field_count = NUM2INT(rb_iv_get(self, "@field_count"));
  field_types = rb_iv_get(self, "@field_types");
  position = NUM2INT(rb_iv_get(self, "@position"));

  if ( position > (row_count - 1) ) {
    rb_iv_set(self, "@values", Qnil);
    return Qfalse;
  }

  rb_iv_set(self, "@opened", Qtrue);

  int enc = -1;
#ifdef HAVE_RUBY_ENCODING_H
  VALUE encoding_id = rb_iv_get(rb_iv_get(self, "@connection"), "@encoding_id");
  if (encoding_id != Qnil) {
    enc = FIX2INT(encoding_id);
  }
#endif

  for ( i = 0; i < field_count; i++ ) {
    field_type = rb_ary_entry(field_types, i);

    // Always return nil if the value returned from Postgres is null
    if (!PQgetisnull(reader, position, i)) {
      value = typecast(PQgetvalue(reader, position, i), PQgetlength(reader, position, i), field_type, enc);
    } else {
      value = Qnil;
    }

    rb_ary_push(array, value);
  }

  rb_iv_set(self, "@values", array);
  rb_iv_set(self, "@position", INT2NUM(position+1));

  return Qtrue;
}

void Init_do_postgres() {
  common_init();

  mPostgres = rb_define_module_under(mDO, "Postgres");
  mEncoding = rb_define_module_under(mPostgres, "Encoding");

  cConnection = DRIVER_CLASS("Connection", cDO_Connection);
  rb_define_method(cConnection, "initialize", cConnection_initialize, 1);
  rb_define_method(cConnection, "dispose", cConnection_dispose, 0);
  rb_define_method(cConnection, "character_set", cConnection_character_set , 0);
  rb_define_method(cConnection, "quote_string", cConnection_quote_string, 1);
  rb_define_method(cConnection, "quote_byte_array", cConnection_quote_byte_array, 1);

  cCommand = DRIVER_CLASS("Command", cDO_Command);
  rb_define_method(cCommand, "set_types", cCommand_set_types, -1);
  rb_define_method(cCommand, "execute_non_query", cCommand_execute_non_query, -1);
  rb_define_method(cCommand, "execute_reader", cCommand_execute_reader, -1);

  cResult = DRIVER_CLASS("Result", cDO_Result);

  cReader = DRIVER_CLASS("Reader", cDO_Reader);
  rb_define_method(cReader, "close", cReader_close, 0);
  rb_define_method(cReader, "next!", cReader_next, 0);
  rb_define_method(cReader, "values", cReader_values, 0);
  rb_define_method(cReader, "fields", cReader_fields, 0);
  rb_define_method(cReader, "field_count", cReader_field_count, 0);

  rb_global_variable(&cResult);
  rb_global_variable(&cReader);

  struct errcodes *errs;

  for (errs = errors; errs->error_name; errs++) {
    rb_const_set(mPostgres, rb_intern(errs->error_name), INT2NUM(errs->error_no));
  }
}
