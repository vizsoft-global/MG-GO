-- Driver security audit events
-- Apply in the admin Supabase project (ytfmsgckjatiserpgdbz).

create table if not exists public.driver_security_events (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (
    event_type in (
      'screenshot_attempt',
      'screen_record_attempt',
      'developer_mode',
      'mock_location',
      'mock_location_blocked_action'
    )
  ),
  severity text not null default 'warning' check (
    severity in ('info', 'warning', 'blocked')
  ),
  context jsonb not null default '{}'::jsonb,
  device jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists driver_security_events_driver_created_idx
  on public.driver_security_events (driver_id, created_at desc);

create index if not exists driver_security_events_event_created_idx
  on public.driver_security_events (event_type, created_at desc);

alter table public.driver_security_events enable row level security;

drop policy if exists "driver_security_events_insert_own" on public.driver_security_events;
create policy "driver_security_events_insert_own"
on public.driver_security_events
for insert
to authenticated
with check (driver_id = auth.uid());

drop policy if exists "driver_security_events_driver_select_none" on public.driver_security_events;
create policy "driver_security_events_driver_select_none"
on public.driver_security_events
for select
to authenticated
using (false);

create or replace function public.driver_log_security_event(
  p_event_type text,
  p_severity text default 'warning',
  p_context jsonb default '{}'::jsonb,
  p_device jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'auth required';
  end if;

  insert into public.driver_security_events (
    driver_id,
    event_type,
    severity,
    context,
    device
  )
  values (
    auth.uid(),
    p_event_type,
    coalesce(nullif(trim(p_severity), ''), 'warning'),
    coalesce(p_context, '{}'::jsonb),
    coalesce(p_device, '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.driver_log_security_event(text, text, jsonb, jsonb)
to authenticated;
