-- Add logo_url column to profiles table
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS logo_url TEXT;

COMMENT ON COLUMN public.profiles.logo_url IS 'URL to the madrasa logo image';

-- Create storage bucket for madrasa logos if not exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('madrasa-logos', 'madrasa-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for logo uploads
CREATE POLICY "Users can view all logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'madrasa-logos');

CREATE POLICY "Users can upload their madrasa logo"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'madrasa-logos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their madrasa logo"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'madrasa-logos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their madrasa logo"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'madrasa-logos' AND
  auth.uid()::text = (storage.foldername(name))[1]
);