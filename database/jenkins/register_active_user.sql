INSERT INTO public.active_users (user_id, user_name)
SELECT user_id, user_name
FROM public.bluegreen_users
WHERE user_id = :'requested_id'::bigint
  AND user_name = :'requested_user'
  AND NOT EXISTS (
      SELECT 1
      FROM public.active_users
      WHERE user_id = :'requested_id'::bigint
         OR user_name = :'requested_user'
  )
RETURNING user_id;
