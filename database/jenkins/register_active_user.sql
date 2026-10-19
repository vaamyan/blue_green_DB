SELECT set_config('bluegreen.requested_user', :'requested_user', false) AS requested_user \gset

DO $$
DECLARE
    v_requested_user text := current_setting('bluegreen.requested_user');
    v_user_id bigint;
BEGIN
    BEGIN
        SELECT user_id
        INTO STRICT v_user_id
        FROM bluegreen_users
        WHERE user_name = v_requested_user;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE EXCEPTION 'User % does not exist in bluegreen_users', v_requested_user;
        WHEN TOO_MANY_ROWS THEN
            RAISE EXCEPTION 'User name % has multiple rows in bluegreen_users', v_requested_user;
    END;

    IF EXISTS (
        SELECT 1
        FROM active_users
        WHERE user_id = v_user_id
          AND user_name = v_requested_user
    ) THEN
        RAISE EXCEPTION 'User % is already active in active_users', v_requested_user;
    END IF;

    INSERT INTO active_users (user_id, user_name)
    VALUES (v_user_id, v_requested_user);

    RAISE NOTICE 'User % registered in active_users', v_requested_user;
END
$$;
