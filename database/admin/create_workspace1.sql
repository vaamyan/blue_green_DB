-- Run as the bluegreen DBA while connected to the postgres database.
CREATE ROLE workspace1 LOGIN;
CREATE DATABASE workspace1 OWNER workspace1;

REVOKE CONNECT ON DATABASE postgres FROM workspace1;
REVOKE CONNECT ON DATABASE template1 FROM workspace1;
REVOKE CONNECT ON DATABASE bluegreen FROM workspace1;
REVOKE CONNECT ON DATABASE workspace1 FROM PUBLIC;
GRANT CONNECT ON DATABASE workspace1 TO workspace1;

\connect workspace1
CREATE SCHEMA workspace1 AUTHORIZATION workspace1;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
