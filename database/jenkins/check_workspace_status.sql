SELECT set_config('bluegreen.requested_user', :'requested_user', false) AS requested_user \gset

DO $$
DECLARE
    v_requested_user text := current_setting('bluegreen.requested_user');
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM bluegreen_users
        WHERE user_name = v_requested_user
    ) THEN
        RAISE EXCEPTION 'User % does not exist in bluegreen_users', v_requested_user;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM active_users
        WHERE user_name = v_requested_user
    ) THEN
        RAISE EXCEPTION 'User % is already active in active_users', v_requested_user;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = v_requested_user
    ) THEN
        RAISE EXCEPTION 'Role % already exists', v_requested_user;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_database
        WHERE datname = v_requested_user
    ) THEN
        RAISE EXCEPTION 'Database % already exists', v_requested_user;
    END IF;

    RAISE NOTICE 'Workspace name % passed the eligibility checks', v_requested_user;
END
$$;
