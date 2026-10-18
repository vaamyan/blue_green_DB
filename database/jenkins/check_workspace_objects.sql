SELECT
    CASE WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'workspace') THEN '1' ELSE '0' END
    || '|'
    || CASE WHEN EXISTS (SELECT 1 FROM pg_database WHERE datname = :'workspace') THEN '1' ELSE '0' END;
