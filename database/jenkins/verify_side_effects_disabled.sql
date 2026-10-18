SELECT CASE
    WHEN EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = format('%I.table_1', :'workspace')::regclass
          AND tgname = 'trigger_1'
          AND tgenabled = 'D'
    )
     AND EXISTS (
        SELECT 1
        FROM pg_rewrite
        WHERE ev_class = format('%I.view_2', :'workspace')::regclass
          AND rulename = 'rule_1'
          AND ev_enabled = 'D'
    )
    THEN 'ok'
    ELSE 'invalid'
END;
