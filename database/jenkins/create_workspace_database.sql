CREATE DATABASE :"workspace" OWNER :"workspace";

REVOKE CONNECT ON DATABASE postgres FROM :"workspace";
REVOKE CONNECT ON DATABASE template1 FROM :"workspace";
REVOKE CONNECT ON DATABASE bluegreen FROM :"workspace";
REVOKE CONNECT ON DATABASE :"workspace" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"workspace" TO :"workspace";
