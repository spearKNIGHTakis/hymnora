-- Hymnora Studio: run once as the Supabase project owner.
-- Draft text is private. Publishing is an explicit, atomic operation.
begin;
create schema if not exists hymnora_private;
revoke all on schema hymnora_private from public, anon, authenticated;
create table if not exists hymnora_private.admins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
revoke all on hymnora_private.admins from public, anon, authenticated;
create or replace function public.hymnora_is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from hymnora_private.admins where user_id=(select auth.uid()));
$$;
revoke all on function public.hymnora_is_admin() from public, anon;
grant execute on function public.hymnora_is_admin() to anon, authenticated;

create table if not exists public.hymns (
 id uuid primary key default gen_random_uuid(),number text not null,title text not null,
 language text not null,is_published boolean not null default false
);
create table if not exists public.hymn_stanzas (
 id uuid primary key default gen_random_uuid(),hymn_id uuid not null references public.hymns(id),
 position integer not null,kind text not null default 'verse',body text not null
);
create table if not exists public.hymn_recordings (
 id uuid primary key default gen_random_uuid(),hymn_id uuid not null references public.hymns(id),
 language text not null,storage_path text not null,is_published boolean not null default false
);
-- Refuse ambiguous identities rather than merging two different hymns.
do $$ begin
 if exists(select 1 from public.hymns group by
  regexp_replace(upper(number),'^EH','PH'),lower(language) having count(*)>1) then
  raise exception 'Duplicate hymn numbers within a language. Resolve these before installing Studio.';
 end if;
end $$;
update public.hymns set number=regexp_replace(upper(number),'^EH','PH') where upper(number) like 'EH%';
create unique index if not exists hymnora_number_language on public.hymns(number,language);
alter table public.hymns add column if not exists source_key text;
alter table public.hymns add column if not exists content_version integer not null default 1;
alter table public.hymns add column if not exists updated_at timestamptz not null default now();
update public.hymns set source_key='local:'||case when lower(language)='twi' then 'twi' else 'english' end||':'||regexp_replace(number,'\D','','g')
 where source_key is null and language in ('Twi','English') and number~'^PH[1-9][0-9]*$';
create unique index if not exists hymnora_source_key on public.hymns(source_key) where source_key is not null;
alter table public.hymn_recordings add column if not exists recording_type text not null default 'unspecified';
alter table public.hymn_recordings add column if not exists performer text not null default '';
alter table public.hymn_recordings add column if not exists storage_bucket text not null default 'hymn-audio';
alter table public.hymn_recordings add column if not exists cues jsonb not null default '[]';
alter table public.hymn_recordings add column if not exists updated_at timestamptz not null default now();
alter table public.hymn_recordings drop constraint if exists hymnora_recording_type;
alter table public.hymn_recordings add constraint hymnora_recording_type check(recording_type in ('male_solo','female_solo','choir','congregation','unspecified'));

create table if not exists public.hymnora_overrides (
 source_key text primary key,hymn_id uuid references public.hymns(id),
 is_visible boolean not null,updated_at timestamptz not null default now()
);
create table if not exists public.hymn_drafts (
 id uuid primary key references public.hymns(id),number text not null,language text not null,
 title text not null,stanzas jsonb not null default '[]',source_key text unique,
 provenance jsonb not null default '{}',reviewed boolean not null default false,
 status text not null default 'draft' check(status in ('draft','review','published','archived')),
 revision integer not null default 1,updated_at timestamptz not null default now(),
 unique(number,language)
);
create table if not exists public.hymn_revisions (
 id bigint generated always as identity primary key,hymn_id uuid not null references public.hymns(id),
 revision integer not null,snapshot jsonb not null,actor uuid references auth.users(id),
 action text not null,created_at timestamptz not null default now()
);
create index if not exists hymnora_revisions_hymn on public.hymn_revisions(hymn_id,created_at desc);
create index if not exists hymnora_stanzas_hymn on public.hymn_stanzas(hymn_id,position);
create index if not exists hymnora_recordings_hymn on public.hymn_recordings(hymn_id,is_published);

-- Replace policies on these application-owned tables; older permissive policies must not bypass admin checks.
do $$ declare p record; t text; begin
 foreach t in array array['hymns','hymn_stanzas','hymn_recordings','hymn_drafts','hymn_revisions','hymnora_overrides'] loop
  execute format('alter table public.%I enable row level security',t);
  for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
   execute format('drop policy %I on public.%I',p.policyname,t);
  end loop;
  execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
end $$;
grant select on public.hymns,public.hymn_stanzas,public.hymn_recordings,public.hymnora_overrides to anon,authenticated;
grant select on public.hymn_drafts,public.hymn_revisions to authenticated;
create policy published_hymns on public.hymns for select to anon,authenticated using(is_published);
create policy admin_hymns on public.hymns for select to authenticated using((select public.hymnora_is_admin()));
create policy published_stanzas on public.hymn_stanzas for select to anon,authenticated using(exists(select 1 from public.hymns h where h.id=hymn_id and h.is_published));
create policy admin_stanzas on public.hymn_stanzas for select to authenticated using((select public.hymnora_is_admin()));
create policy published_recordings on public.hymn_recordings for select to anon,authenticated using(is_published and storage_bucket='hymn-audio' and exists(select 1 from public.hymns h where h.id=hymn_id and h.is_published));
create policy admin_recordings on public.hymn_recordings for select to authenticated using((select public.hymnora_is_admin()));
create policy catalogue_visibility on public.hymnora_overrides for select to anon,authenticated using(true);
create policy private_drafts on public.hymn_drafts for select to authenticated using((select public.hymnora_is_admin()));
create policy private_history on public.hymn_revisions for select to authenticated using((select public.hymnora_is_admin()));

create or replace function public.hymnora_save_hymn(p_document jsonb,p_expected_revision integer default null)
returns public.hymn_drafts language plpgsql security definer set search_path='' as $$
declare d public.hymn_drafts; hid uuid; num text; lang text; sk text; verses jsonb; wanted text;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501'; end if;
 num:=upper(regexp_replace(trim(p_document->>'number'),'\s','','g'));lang:=p_document->>'language';
 if num !~ '^PH[1-9][0-9]*$' or lang not in ('English','Twi') or length(trim(coalesce(p_document->>'title','')))=0 then
  raise exception 'A PH number, language and title are required';end if;
 verses:=coalesce(p_document->'stanzas','[]'::jsonb);
 if jsonb_typeof(verses)<>'array' then raise exception 'Lyrics must be an array';end if;
 if exists(select 1 from jsonb_array_elements(verses) s where coalesce(s->>'kind','verse') not in ('verse','chorus')) then raise exception 'Invalid stanza kind';end if;
 wanted:=coalesce(p_document->>'status','draft');
 if wanted not in ('draft','review') then raise exception 'Use the publish or unpublish action';end if;
 if wanted='review' and (not coalesce((p_document->>'reviewed')::boolean,false) or jsonb_array_length(verses)=0
  or exists(select 1 from jsonb_array_elements(verses) s where length(trim(coalesce(s->>'body','')))=0)) then
  raise exception 'Proofread every verse before sending for review';end if;
 sk:=coalesce(nullif(p_document->>'source_key',''),'local:'||case when lang='Twi' then 'twi' else 'english' end||':'||substring(num from 3));
 if nullif(p_document->>'id','') is not null then
  select * into d from public.hymn_drafts where id=(p_document->>'id')::uuid for update;
  if not found then raise exception 'Hymn draft not found';end if;
 else
  select * into d from public.hymn_drafts where number=num and language=lang for update;
 end if;
 if d.id is not null and (p_expected_revision is null or d.revision<>p_expected_revision) then
  raise exception 'This hymn changed in another session. Reload before saving.' using errcode='40001';end if;
 if d.id is null then
  select id into hid from public.hymns where number=num and language=lang;
  if hid is null then
   hid:=gen_random_uuid();
   insert into public.hymns(id,number,title,language,is_published,source_key) values(hid,num,trim(p_document->>'title'),lang,false,sk);
  end if;
  insert into public.hymn_drafts(id,number,language,title,stanzas,source_key,provenance,reviewed,status)
   values(hid,num,lang,trim(p_document->>'title'),verses,sk,coalesce(p_document->'provenance','{}'),coalesce((p_document->>'reviewed')::boolean,false),wanted) returning * into d;
 else
  update public.hymn_drafts set number=num,language=lang,title=trim(p_document->>'title'),stanzas=verses,
   reviewed=coalesce((p_document->>'reviewed')::boolean,false),status=wanted,revision=revision+1,updated_at=now()
   where id=d.id returning * into d;
 end if;
 insert into public.hymn_revisions(hymn_id,revision,snapshot,actor,action) values(d.id,d.revision,to_jsonb(d),auth.uid(),'save');
 return d;
end $$;

create or replace function public.hymnora_publish_hymn(p_id uuid,p_expected_revision integer)
returns public.hymn_drafts language plpgsql security definer set search_path='' as $$
declare d public.hymn_drafts; v_stanza jsonb; pos integer:=0;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 select * into d from public.hymn_drafts where id=p_id for update;
 if not found or d.revision<>p_expected_revision then raise exception 'Reload the current hymn revision' using errcode='40001';end if;
 if d.status<>'review' or not d.reviewed or jsonb_array_length(d.stanzas)=0 then raise exception 'A proofread review draft is required';end if;
 if exists(select 1 from jsonb_array_elements(d.stanzas) s where length(trim(coalesce(s->>'body','')))=0) then raise exception 'Empty verses cannot be published';end if;
 update public.hymns set number=d.number,language=d.language,title=d.title,source_key=d.source_key,
  is_published=true,content_version=content_version+1,updated_at=now() where id=p_id;
 delete from public.hymn_stanzas where hymn_id=p_id;
 for v_stanza in select value from jsonb_array_elements(d.stanzas) loop
  pos:=pos+1;insert into public.hymn_stanzas(id,hymn_id,position,kind,body) values(gen_random_uuid(),p_id,pos,coalesce(v_stanza->>'kind','verse'),trim(v_stanza->>'body'));
 end loop;
 insert into public.hymnora_overrides(source_key,hymn_id,is_visible) values(d.source_key,d.id,true)
  on conflict(source_key) do update set hymn_id=excluded.hymn_id,is_visible=true,updated_at=now();
 update public.hymn_drafts set status='published',revision=revision+1,updated_at=now() where id=p_id returning * into d;
 insert into public.hymn_revisions(hymn_id,revision,snapshot,actor,action) values(d.id,d.revision,to_jsonb(d),auth.uid(),'publish');return d;
end $$;

create or replace function public.hymnora_unpublish_hymn(p_id uuid,p_expected_revision integer)
returns public.hymn_drafts language plpgsql security definer set search_path='' as $$
declare d public.hymn_drafts;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 select * into d from public.hymn_drafts where id=p_id for update;
 if not found or d.revision<>p_expected_revision then raise exception 'Reload the current hymn revision' using errcode='40001';end if;
 update public.hymns set is_published=false,updated_at=now() where id=p_id;
 insert into public.hymnora_overrides(source_key,hymn_id,is_visible) values(d.source_key,d.id,false)
  on conflict(source_key) do update set is_visible=false,updated_at=now();
 update public.hymn_drafts set status='archived',revision=revision+1,updated_at=now() where id=p_id returning * into d;
 insert into public.hymn_revisions(hymn_id,revision,snapshot,actor,action) values(d.id,d.revision,to_jsonb(d),auth.uid(),'unpublish');return d;
end $$;

create or replace function public.hymnora_import_catalogue(p_items jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare item jsonb; n integer:=0; num text;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)>50 then raise exception 'Import at most 50 hymns per batch';end if;
 for item in select value from jsonb_array_elements(p_items) loop
  num:=regexp_replace(upper(item->>'number'),'^EH','PH');
  if not exists(select 1 from public.hymn_drafts where number=num and language=item->>'language') then
   perform public.hymnora_save_hymn(jsonb_build_object('number',num,'language',item->>'language','title',item->>'title',
    'source_key',item->>'id','stanzas',item->'stanzas','status','draft','reviewed',false,
    'provenance',jsonb_build_object('source',item->>'source','source_page',item->'source_page','review',item->'review')),null);
   n:=n+1;
  end if;
 end loop;return n;
end $$;

create or replace function public.hymnora_save_recording(p_document jsonb) returns public.hymn_recordings
language plpgsql security definer set search_path='' as $$
declare r public.hymn_recordings; rid uuid; hid uuid; kind text; path text; v_cues jsonb;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 rid:=coalesce(nullif(p_document->>'id','')::uuid,gen_random_uuid());hid:=(p_document->>'hymn_id')::uuid;
 kind:=coalesce(p_document->>'recording_type','unspecified');path:=p_document->>'storage_path';v_cues:=coalesce(p_document->'cues','[]');
 if kind not in ('male_solo','female_solo','choir','congregation','unspecified') or path is null or path~'(^/|\.\.)' then raise exception 'Invalid recording metadata';end if;
 if jsonb_typeof(v_cues)<>'array' then raise exception 'Invalid verse timing markers';end if;
 if exists(select 1 from jsonb_array_elements(v_cues) c where (c->>'position')::integer<1 or (c->>'milliseconds')::bigint<0) then raise exception 'Invalid verse timing markers';end if;
 if exists(select 1 from public.hymn_recordings where id=rid) then
  update public.hymn_recordings set recording_type=kind,performer=coalesce(p_document->>'performer',''),cues=v_cues,updated_at=now() where id=rid returning * into r;
 else
  insert into public.hymn_recordings(id,hymn_id,language,storage_path,storage_bucket,is_published,recording_type,performer,cues)
   select rid,hid,h.language,path,'hymn-audio-drafts',false,kind,coalesce(p_document->>'performer',''),v_cues from public.hymns h where h.id=hid returning * into r;
 end if;
 if r.id is null then raise exception 'Save the hymn before adding a recording';end if;return r;
end $$;
create or replace function public.hymnora_set_recording_publication(p_id uuid,p_publish boolean) returns public.hymn_recordings
language plpgsql security definer set search_path='' as $$
declare r public.hymn_recordings;
begin
 if not public.hymnora_is_admin() then raise exception 'Admin access required' using errcode='42501';end if;
 select * into r from public.hymn_recordings where id=p_id for update;
 if not found then raise exception 'Recording not found';end if;
 if p_publish and not exists(select 1 from public.hymns where id=r.hymn_id and is_published) then raise exception 'Publish the hymn before its recordings';end if;
 if p_publish and r.recording_type='unspecified' then raise exception 'Choose a recording type first';end if;
 if p_publish and not exists(select 1 from storage.objects where bucket_id='hymn-audio' and name=r.storage_path) then raise exception 'Copy the audio into the public bucket before publishing';end if;
 update public.hymn_recordings set is_published=p_publish,storage_bucket=case when p_publish then 'hymn-audio' else 'hymn-audio-drafts' end,updated_at=now() where id=p_id returning * into r;return r;
end $$;

-- Explicit RPC grants; the public key cannot perform content writes.
revoke all on function public.hymnora_save_hymn(jsonb,integer),public.hymnora_publish_hymn(uuid,integer),public.hymnora_unpublish_hymn(uuid,integer),public.hymnora_import_catalogue(jsonb),public.hymnora_save_recording(jsonb),public.hymnora_set_recording_publication(uuid,boolean) from public,anon;
grant execute on function public.hymnora_save_hymn(jsonb,integer),public.hymnora_publish_hymn(uuid,integer),public.hymnora_unpublish_hymn(uuid,integer),public.hymnora_import_catalogue(jsonb),public.hymnora_save_recording(jsonb),public.hymnora_set_recording_publication(uuid,boolean) to authenticated;
insert into storage.buckets(id,name,public) values('hymn-audio','hymn-audio',true),('hymn-audio-drafts','hymn-audio-drafts',false),('hymn-source-documents','hymn-source-documents',false)
 on conflict(id) do nothing;
-- RESTRICTIVE guard also constrains any pre-existing broad storage write policy.
drop policy if exists hymnora_storage_write_guard on storage.objects;
create policy hymnora_storage_write_guard on storage.objects as restrictive for all to anon,authenticated
 using(bucket_id not in ('hymn-audio','hymn-audio-drafts','hymn-source-documents') or (select auth.uid()) is not null and (select public.hymnora_is_admin()))
 with check(bucket_id not in ('hymn-audio','hymn-audio-drafts','hymn-source-documents') or (select auth.uid()) is not null and (select public.hymnora_is_admin()));
drop policy if exists hymnora_admin_storage on storage.objects;
create policy hymnora_admin_storage on storage.objects for all to authenticated
 using(bucket_id in ('hymn-audio','hymn-audio-drafts','hymn-source-documents') and (select public.hymnora_is_admin()))
 with check(bucket_id in ('hymn-audio','hymn-audio-drafts','hymn-source-documents') and (select public.hymnora_is_admin()));
notify pgrst,'reload schema';
commit;
