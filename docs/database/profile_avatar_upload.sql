-- Apply to an existing Supabase project; docs/supabase_schema.sql is the recovery source.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('profile-avatars', 'profile-avatars', false, 2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[])
ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp']::text[];

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'profile_avatars_insert_own') THEN
    CREATE POLICY profile_avatars_insert_own ON storage.objects FOR INSERT TO authenticated
      WITH CHECK (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'profile_avatars_update_own') THEN
    CREATE POLICY profile_avatars_update_own ON storage.objects FOR UPDATE TO authenticated
      USING (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text)
      WITH CHECK (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'profile_avatars_select_own') THEN
    CREATE POLICY profile_avatars_select_own ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'profile-avatars' AND (storage.foldername(name))[1] = (SELECT auth.uid())::text);
  END IF;
END $$;

