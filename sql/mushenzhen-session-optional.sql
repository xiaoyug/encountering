-- Optional. Sunny can run this in the Supabase SQL editor.
-- The upload page does not need these columns. If they are missing, the
-- photo still saves under event = mushenzhen-2026 and the session is dropped.
-- If they exist, the row also stores the sola session the guest picked.

alter table public.photos add column if not exists session_id text;
alter table public.photos add column if not exists session_title text;
