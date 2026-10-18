SET search_path TO :"workspace", pg_catalog;

DO $$
BEGIN
    IF (SELECT count(*) FROM table_1) < 5 THEN
        RAISE EXCEPTION 'Fixture validation failed for table_1';
    END IF;
    IF (SELECT count(*) FROM table_2) < 3 THEN
        RAISE EXCEPTION 'Fixture validation failed for table_2';
    END IF;
    IF (SELECT count(*) FROM table_4) < 2 THEN
        RAISE EXCEPTION 'Fixture validation failed for table_4';
    END IF;
    IF (SELECT count(*) FROM table_5) < 4 THEN
        RAISE EXCEPTION 'Fixture validation failed for table_5';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'table_1'::regclass
          AND tgname = 'trigger_1'
          AND tgenabled = 'O'
    ) THEN
        RAISE EXCEPTION 'Trigger validation failed for trigger_1';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_rewrite
        WHERE ev_class = 'view_2'::regclass
          AND rulename = 'rule_1'
          AND ev_enabled = 'O'
    ) THEN
        RAISE EXCEPTION 'Rule validation failed for rule_1';
    END IF;
    IF COALESCE((
        SELECT relispopulated
        FROM pg_class
        WHERE oid = 'materialized_view_1'::regclass
    ), false) IS NOT TRUE THEN
        RAISE EXCEPTION 'Materialized view validation failed for materialized_view_1';
    END IF;
END;
$$;
