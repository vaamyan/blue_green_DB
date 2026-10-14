-- Run as the bluegreen DBA while connected to the postgres database.
CREATE ROLE workspace2 LOGIN;
CREATE DATABASE workspace2 OWNER workspace2;

REVOKE CONNECT ON DATABASE postgres FROM workspace2;
REVOKE CONNECT ON DATABASE template1 FROM workspace2;
REVOKE CONNECT ON DATABASE bluegreen FROM workspace2;
REVOKE CONNECT ON DATABASE workspace2 FROM PUBLIC;
GRANT CONNECT ON DATABASE workspace2 TO workspace2;

\connect workspace2
CREATE SCHEMA workspace2 AUTHORIZATION workspace2;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
