-- Idempotent owner edit/delete permissions for an existing project.
-- The main recovery schema includes these policies and grants.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'community_posts'
      AND policyname = 'community_posts_update_own'
  ) THEN
    CREATE POLICY community_posts_update_own ON public.community_posts
      FOR UPDATE TO authenticated
      USING ((SELECT auth.uid()) = user_id)
      WITH CHECK ((SELECT auth.uid()) = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'community_posts'
      AND policyname = 'community_posts_delete_own'
  ) THEN
    CREATE POLICY community_posts_delete_own ON public.community_posts
      FOR DELETE TO authenticated
      USING ((SELECT auth.uid()) = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'community_photos_delete_own'
  ) THEN
    CREATE POLICY community_photos_delete_own ON storage.objects
      FOR DELETE TO authenticated
      USING (bucket_id = 'community-photos'
        AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
  END IF;
END $$;

GRANT UPDATE (body, place, topic, photo_paths), DELETE
  ON public.community_posts TO authenticated;
