SELECT CASE
    WHEN EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = format('%I.table_1', :'workspace')::regclass
          AND tgname = 'trigger_1'
          AND tgenabled = 'D'
    )
    THEN 'ok'
    ELSE 'invalid'
END;
