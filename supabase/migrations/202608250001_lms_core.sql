create extension if not exists pgcrypto;
create schema if not exists private;

create type public.app_role as enum ('student','teacher','reviewer','admin');
create type public.item_status as enum ('draft','review','revision','approved','retired');
create type public.exam_status as enum ('draft','published','closed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role public.app_role not null default 'student',
  school_name text,
  created_at timestamptz not null default now()
);
create table public.subjects (id uuid primary key default gen_random_uuid(),code text unique not null,name text not null,active boolean not null default true);
create table public.question_items (
  id uuid primary key default gen_random_uuid(), subject_id uuid not null references public.subjects(id), code text unique not null,
  stem text not null, options jsonb not null default '[]', item_type text not null default 'single_choice', topic text,
  cognitive_level text check (cognitive_level in ('recognition','comprehension','application')), difficulty_target numeric(4,3),
  status public.item_status not null default 'draft', version integer not null default 1, created_by uuid references public.profiles(id), approved_by uuid references public.profiles(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check (jsonb_typeof(options)='array')
);
create table public.question_keys (question_id uuid primary key references public.question_items(id) on delete cascade,correct_answer jsonb not null,explanation text,updated_at timestamptz not null default now());
create table public.item_reviews (id uuid primary key default gen_random_uuid(),question_id uuid not null references public.question_items(id),reviewer_id uuid not null references public.profiles(id),decision text not null check(decision in('approve','revise','reject')),comment text,created_at timestamptz not null default now());
create table public.blueprints (id uuid primary key default gen_random_uuid(),subject_id uuid not null references public.subjects(id),name text not null,year integer not null default 2026,specification jsonb not null default '{}',status text not null default 'draft',created_at timestamptz not null default now());
create table public.exams (id uuid primary key default gen_random_uuid(),subject_id uuid not null references public.subjects(id),blueprint_id uuid references public.blueprints(id),title text not null,duration_minutes integer not null check(duration_minutes>0),status public.exam_status not null default 'draft',starts_at timestamptz,ends_at timestamptz,created_by uuid references public.profiles(id),created_at timestamptz not null default now());
create table public.exam_questions (exam_id uuid references public.exams(id) on delete cascade,question_id uuid references public.question_items(id),position integer not null,points numeric(6,2) not null default 0.25,primary key(exam_id,question_id),unique(exam_id,position));
create table public.attempts (id uuid primary key default gen_random_uuid(),exam_id uuid not null references public.exams(id),student_id uuid not null references public.profiles(id),started_at timestamptz not null default now(),submitted_at timestamptz,score numeric(7,2),status text not null default 'in_progress',unique(exam_id,student_id));
create table public.responses (id uuid primary key default gen_random_uuid(),attempt_id uuid not null references public.attempts(id) on delete cascade,question_id uuid not null references public.question_items(id),answer jsonb not null,is_correct boolean,score numeric(6,2),saved_at timestamptz not null default now(),unique(attempt_id,question_id));
create table public.violations (id bigint generated always as identity primary key,attempt_id uuid not null references public.attempts(id) on delete cascade,event_type text not null,details jsonb not null default '{}',occurred_at timestamptz not null default now());
create table public.external_resources (id uuid primary key default gen_random_uuid(),title text not null,url text not null,category text,active boolean not null default true,sort_order integer not null default 0);
create table public.audit_logs (id bigint generated always as identity primary key,actor_id uuid references public.profiles(id),action text not null,entity_type text not null,entity_id text,details jsonb not null default '{}',created_at timestamptz not null default now());

create index on public.question_items(subject_id,status);create index on public.exams(subject_id,status);create index on public.attempts(student_id);create index on public.responses(attempt_id);create index on public.violations(attempt_id,occurred_at);

create or replace function private.is_staff() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.profiles where id=(select auth.uid()) and role in ('teacher','reviewer','admin'))$$;
revoke all on function private.is_staff() from public;grant execute on function private.is_staff() to authenticated;
create or replace function private.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.profiles(id,full_name) values(new.id,new.raw_user_meta_data->>'full_name');return new;end$$;
revoke all on function private.handle_new_user() from public;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

alter table public.profiles enable row level security;alter table public.subjects enable row level security;alter table public.question_items enable row level security;alter table public.question_keys enable row level security;alter table public.item_reviews enable row level security;alter table public.blueprints enable row level security;alter table public.exams enable row level security;alter table public.exam_questions enable row level security;alter table public.attempts enable row level security;alter table public.responses enable row level security;alter table public.violations enable row level security;alter table public.external_resources enable row level security;alter table public.audit_logs enable row level security;

create policy profiles_self_read on public.profiles for select to authenticated using(id=(select auth.uid()) or (select private.is_staff()));
create policy subjects_read on public.subjects for select to authenticated using(true);create policy subjects_staff on public.subjects for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy items_read on public.question_items for select to authenticated using(status='approved' or created_by=(select auth.uid()) or (select private.is_staff()));create policy items_staff_write on public.question_items for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy keys_staff_only on public.question_keys for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy reviews_staff on public.item_reviews for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy blueprints_read on public.blueprints for select to authenticated using(status='published' or (select private.is_staff()));create policy blueprints_staff on public.blueprints for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy exams_read on public.exams for select to authenticated using(status='published' or (select private.is_staff()));create policy exams_staff on public.exams for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy exam_questions_read on public.exam_questions for select to authenticated using(exists(select 1 from public.exams e where e.id=exam_id and (e.status='published' or (select private.is_staff()))));create policy exam_questions_staff on public.exam_questions for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));
create policy attempts_own_read on public.attempts for select to authenticated using(student_id=(select auth.uid()) or (select private.is_staff()));create policy attempts_own_insert on public.attempts for insert to authenticated with check(student_id=(select auth.uid()));create policy attempts_own_update on public.attempts for update to authenticated using(student_id=(select auth.uid())) with check(student_id=(select auth.uid()));
create policy responses_own_read on public.responses for select to authenticated using(exists(select 1 from public.attempts a where a.id=attempt_id and (a.student_id=(select auth.uid()) or (select private.is_staff()))));create policy responses_own_write on public.responses for insert to authenticated with check(exists(select 1 from public.attempts a where a.id=attempt_id and a.student_id=(select auth.uid()) and a.submitted_at is null));create policy responses_own_update on public.responses for update to authenticated using(exists(select 1 from public.attempts a where a.id=attempt_id and a.student_id=(select auth.uid()) and a.submitted_at is null)) with check(exists(select 1 from public.attempts a where a.id=attempt_id and a.student_id=(select auth.uid()) and a.submitted_at is null));
create policy violations_own_insert on public.violations for insert to authenticated with check(exists(select 1 from public.attempts a where a.id=attempt_id and a.student_id=(select auth.uid())));create policy violations_read on public.violations for select to authenticated using(exists(select 1 from public.attempts a where a.id=attempt_id and (a.student_id=(select auth.uid()) or (select private.is_staff()))));
create policy resources_read on public.external_resources for select to authenticated using(active);create policy resources_staff on public.external_resources for all to authenticated using((select private.is_staff())) with check((select private.is_staff()));create policy audit_staff on public.audit_logs for select to authenticated using((select private.is_staff()));

insert into public.subjects(code,name) values('TOAN','Toán'),('NGUVAN','Ngữ văn'),('TIENGANH','Tiếng Anh'),('VATLI','Vật lí'),('HOAHOC','Hóa học'),('SINHHOC','Sinh học'),('LICHSU','Lịch sử'),('DIALI','Địa lí'),('GDKTPL','Giáo dục kinh tế và pháp luật'),('TINHOC','Tin học'),('CONGNGHE','Công nghệ') on conflict do nothing;
insert into public.external_resources(title,url,category,sort_order) values('Phòng học ảo','https://huycomf2020.github.io/phong_hoc_ao/index.html','learning',1),('Không gian giáo viên','https://huycomf2020.github.io/giao_vien/index.html','teacher',2);
