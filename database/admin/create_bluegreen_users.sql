-- Run as bluegreen while connected to the bluegreen database.
CREATE TABLE IF NOT EXISTS public.bluegreen_users (
    user_id bigint NOT NULL,
    user_name text NOT NULL,
    CONSTRAINT constraint_1 UNIQUE (user_name),
    CONSTRAINT constraint_2 CHECK (user_name = btrim(user_name) AND user_name <> '')
);

CREATE TABLE IF NOT EXISTS public.active_users (
    user_id bigint NOT NULL,
    user_name text NOT NULL,
    CONSTRAINT constraint_3 UNIQUE (user_name),
    CONSTRAINT constraint_4 CHECK (user_name = btrim(user_name) AND user_name <> '')
);

-- Migrate an earlier prototype that generated user_id and used it as the primary key.
DO $$
DECLARE
    table_name text;
    primary_key_name name;
BEGIN
    FOREACH table_name IN ARRAY ARRAY['bluegreen_users', 'active_users'] LOOP
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN user_id DROP IDENTITY IF EXISTS', table_name);
        EXECUTE format('ALTER TABLE public.%I ALTER COLUMN user_id DROP DEFAULT', table_name);

        SELECT conname
        INTO primary_key_name
        FROM pg_constraint
        WHERE conrelid = format('public.%I', table_name)::regclass
          AND contype = 'p';

        IF primary_key_name IS NOT NULL THEN
            EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', table_name, primary_key_name);
        END IF;
        primary_key_name := NULL;
    END LOOP;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS index_1 ON public.bluegreen_users (user_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_2 ON public.active_users (user_id);
