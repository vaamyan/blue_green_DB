CREATE ROLE :"workspace"
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    NOBYPASSRLS;

CREATE DATABASE :"workspace" OWNER :"workspace";

REVOKE CONNECT ON DATABASE postgres FROM :"workspace";
REVOKE CONNECT ON DATABASE template1 FROM :"workspace";
REVOKE CONNECT ON DATABASE bluegreen FROM :"workspace";
REVOKE CONNECT ON DATABASE :"workspace" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"workspace" TO :"workspace";

\connect :"workspace"

CREATE SCHEMA :"workspace" AUTHORIZATION :"workspace";
REVOKE ALL ON SCHEMA public FROM PUBLIC;
