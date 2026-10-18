SELECT user_id
FROM public.bluegreen_users
WHERE user_name = :'requested_user';
