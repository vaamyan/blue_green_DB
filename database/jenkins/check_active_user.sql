SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM active_users
    WHERE user_id = :'requested_id'::bigint
       AND user_name = :'requested_user'
) THEN '1' ELSE '0' END;
