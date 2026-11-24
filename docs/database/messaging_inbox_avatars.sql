BEGIN;
DROP FUNCTION IF EXISTS public.private_inbox();
CREATE OR REPLACE FUNCTION public.private_inbox()
RETURNS TABLE (conversation_id uuid, other_user_id uuid, display_name text, last_activity_at timestamptz, preview text, message_at timestamptz, unread_count bigint, avatar_path text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT c.id, other.id, COALESCE(NULLIF(btrim(p.full_name),''),'Traveller'), c.last_activity_at, latest.content, latest.created_at,
    (SELECT count(*) FROM public.private_messages u WHERE u.conversation_id=c.id AND u.sender_id<>(SELECT auth.uid()) AND u.read_at IS NULL),
    CASE WHEN p.avatar_url IN (other.id || '/avatar.jpg', other.id || '/avatar.png', other.id || '/avatar.webp') THEN p.avatar_url END
  FROM public.private_conversations c
  CROSS JOIN LATERAL (SELECT CASE WHEN c.participant_low=(SELECT auth.uid()) THEN c.participant_high ELSE c.participant_low END AS id) other
  LEFT JOIN public.profiles p ON p.user_id=other.id
  LEFT JOIN LATERAL (SELECT m.content,m.created_at FROM public.private_messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC,m.id DESC LIMIT 1) latest ON true
  WHERE (SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) IN (c.participant_low,c.participant_high)
  ORDER BY c.last_activity_at DESC,c.id DESC
$$;
REVOKE ALL ON FUNCTION public.private_inbox() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.private_inbox() TO authenticated;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='profile_avatars_select_conversation_partner') THEN
    CREATE POLICY profile_avatars_select_conversation_partner ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'profile-avatars' AND EXISTS (
        SELECT 1 FROM public.private_conversations c
        CROSS JOIN LATERAL (SELECT CASE WHEN c.participant_low=(SELECT auth.uid()) THEN c.participant_high ELSE c.participant_low END AS id) other
        WHERE (SELECT auth.uid()) IN (c.participant_low, c.participant_high)
          AND storage.objects.name IN (other.id || '/avatar.jpg', other.id || '/avatar.png', other.id || '/avatar.webp')
      ));
  END IF;
END $$;
COMMIT;
