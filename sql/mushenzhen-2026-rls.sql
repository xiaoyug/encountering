-- muShenzhen 2026 · 观众照片墙权限收紧
-- Sunny（xiaoyug）在 Supabase Dashboard → SQL Editor 整段执行。
-- 不会随代码部署自动执行。执行前若项目暂停，先 Resume。
--
-- 1. 单独建活动 mushenzhen-2026，不改 mufriends-2026-11-06 里已有的照片。
-- 2. 手机只能 INSERT 新照片：说明（message）和自愿填写的联系文字（nickname）有长度上限。
--    联系文字可以是空的。不能改 photo_url，不能把照片挪到别的活动。
-- 3. 大屏按 M 隐藏照片仍用同一个匿名密钥，而且只能把 deleted 从 false 改成 true。
--    M 没有密码。打开大屏的人按 M，或直接调用这个更新，都能隐藏照片。这是已知风险。
-- 4. 活动名称和日期也可以被匿名密钥改（上传页的名称/日期，以及大屏 M 里的活动编辑）。
--    同样没有密码。
--
-- 同意文案还没有法务签字，不在这个脚本里。

begin;

insert into public.events (slug, name, date, slogan)
values ('mushenzhen-2026', 'muShenzhen 2026', '2026-11-29', '')
on conflict (slug) do nothing;

-- 若大屏先被打开，自动建档会把 name 写成 slug。只修正这种还没改过的行。
update public.events
set name = 'muShenzhen 2026',
    date = '2026-11-29'
where slug = 'mushenzhen-2026'
  and name in ('mushenzhen-2026', '');

drop policy if exists "photos anon update" on public.photos;
drop policy if exists "anon mark deleted" on public.photos;
drop policy if exists "photos anon delete" on public.photos;
drop policy if exists "anon delete" on public.photos;
drop policy if exists "photos anon insert" on public.photos;
drop policy if exists "anon insert" on public.photos;
drop policy if exists "photos anon insert own upload" on public.photos;
drop policy if exists "photos anon soft delete only" on public.photos;

create policy "photos anon insert own upload" on public.photos
  for insert to anon
  with check (
    deleted = false
    and char_length(coalesce(nickname, '')) <= 80
    and char_length(coalesce(message, '')) <= 140
    and event <> 'mufriends-2026-11-06'
    and photo_url like 'https://mufriends.mushenzhen.xyz/proxy/storage/v1/object/public/photos/%'
  );

create policy "photos anon soft delete only" on public.photos
  for update to anon
  using (deleted = false)
  with check (deleted = true);

revoke update, delete on table public.photos from anon, authenticated;
grant update (deleted) on table public.photos to anon;

-- 列权限之外再挡一层。Dashboard（没有 JWT）和 service_role 不受影响。
create or replace function public.photos_anon_soft_delete_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() in ('anon', 'authenticated') then
    if old.deleted is true then
      raise exception 'photo is already hidden';
    end if;
    if new.deleted is distinct from true
       or new.id is distinct from old.id
       or new.nickname is distinct from old.nickname
       or new.message is distinct from old.message
       or new.photo_url is distinct from old.photo_url
       or new.event is distinct from old.event
       or new.created_at is distinct from old.created_at
    then
      raise exception 'anonymous clients may only hide a photo';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.photos_anon_soft_delete_only() from public, anon, authenticated;

drop trigger if exists photos_anon_soft_delete_only on public.photos;
create trigger photos_anon_soft_delete_only
  before update on public.photos
  for each row
  execute function public.photos_anon_soft_delete_only();

-- 存储桶保持公开读和匿名上传。若以前加过匿名改/删文件的策略，去掉。
drop policy if exists "photos bucket anon update" on storage.objects;
drop policy if exists "photos bucket anon delete" on storage.objects;
drop policy if exists "anon update files" on storage.objects;
drop policy if exists "anon delete files" on storage.objects;

commit;

notify pgrst, 'reload schema';
