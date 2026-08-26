begin;
create table if not exists public.teacher_subjects(teacher_id uuid not null references public.profiles(id) on delete cascade,subject_id uuid not null references public.subjects(id) on delete cascade,assigned_at timestamptz not null default now(),assigned_by uuid references public.profiles(id),primary key(teacher_id,subject_id));
create index if not exists teacher_subjects_subject_id_idx on public.teacher_subjects(subject_id);
create index if not exists teacher_subjects_assigned_by_idx on public.teacher_subjects(assigned_by);
alter table public.teacher_subjects enable row level security;
alter table public.external_resources add column if not exists subject_id uuid references public.subjects(id);
create index if not exists external_resources_subject_id_idx on public.external_resources(subject_id);

create or replace function private.current_app_role() returns public.app_role language sql stable security definer set search_path='' as $$select role from public.profiles where id=(select auth.uid())$$;
revoke all on function private.current_app_role() from public,anon;grant execute on function private.current_app_role() to authenticated;
create or replace function private.can_access_subject(p_subject_id uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and (p.role in('admin','reviewer') or (p.role='teacher' and exists(select 1 from public.teacher_subjects ts where ts.teacher_id=p.id and ts.subject_id=p_subject_id))))$$;
revoke all on function private.can_access_subject(uuid) from public,anon;grant execute on function private.can_access_subject(uuid) to authenticated;

drop policy if exists teacher_subjects_read on public.teacher_subjects;drop policy if exists teacher_subjects_admin on public.teacher_subjects;
create policy teacher_subjects_read on public.teacher_subjects for select to authenticated using(teacher_id=(select auth.uid()) or (select private.current_app_role()) in('admin','reviewer'));
create policy teacher_subjects_admin_insert on public.teacher_subjects for insert to authenticated with check((select private.current_app_role())='admin');
create policy teacher_subjects_admin_update on public.teacher_subjects for update to authenticated using((select private.current_app_role())='admin') with check((select private.current_app_role())='admin');
create policy teacher_subjects_admin_delete on public.teacher_subjects for delete to authenticated using((select private.current_app_role())='admin');

drop policy if exists subjects_read on public.subjects;drop policy if exists subjects_staff on public.subjects;
create policy subjects_read on public.subjects for select to authenticated using((select private.current_app_role())='student' or (select private.can_access_subject(id)));
create policy subjects_admin_insert on public.subjects for insert to authenticated with check((select private.current_app_role())='admin');
create policy subjects_admin_update on public.subjects for update to authenticated using((select private.current_app_role())='admin') with check((select private.current_app_role())='admin');
create policy subjects_admin_delete on public.subjects for delete to authenticated using((select private.current_app_role())='admin');

drop policy if exists items_read on public.question_items;drop policy if exists items_staff_write on public.question_items;
create policy items_scoped_read on public.question_items for select to authenticated using(((select private.current_app_role())='student' and status='approved') or (select private.can_access_subject(subject_id)));
create policy items_scoped_insert on public.question_items for insert to authenticated with check((select private.can_access_subject(subject_id)));
create policy items_scoped_update on public.question_items for update to authenticated using((select private.can_access_subject(subject_id))) with check((select private.can_access_subject(subject_id)));
create policy items_scoped_delete on public.question_items for delete to authenticated using((select private.can_access_subject(subject_id)));
drop policy if exists keys_staff_only on public.question_keys;
create policy keys_subject_staff on public.question_keys for all to authenticated using(exists(select 1 from public.question_items q where q.id=question_id and (select private.can_access_subject(q.subject_id)))) with check(exists(select 1 from public.question_items q where q.id=question_id and (select private.can_access_subject(q.subject_id))));
drop policy if exists reviews_staff on public.item_reviews;
create policy reviews_subject_staff on public.item_reviews for all to authenticated using(exists(select 1 from public.question_items q where q.id=question_id and (select private.can_access_subject(q.subject_id)))) with check(exists(select 1 from public.question_items q where q.id=question_id and (select private.can_access_subject(q.subject_id))));

drop policy if exists blueprints_read on public.blueprints;drop policy if exists blueprints_staff on public.blueprints;
create policy blueprints_scoped_read on public.blueprints for select to authenticated using(((select private.current_app_role())='student' and status='published') or (select private.can_access_subject(subject_id)));
create policy blueprints_scoped_insert on public.blueprints for insert to authenticated with check((select private.can_access_subject(subject_id)));
create policy blueprints_scoped_update on public.blueprints for update to authenticated using((select private.can_access_subject(subject_id))) with check((select private.can_access_subject(subject_id)));
create policy blueprints_scoped_delete on public.blueprints for delete to authenticated using((select private.can_access_subject(subject_id)));
drop policy if exists exams_read on public.exams;drop policy if exists exams_staff on public.exams;
create policy exams_scoped_read on public.exams for select to authenticated using(((select private.current_app_role())='student' and status='published') or (select private.can_access_subject(subject_id)));
create policy exams_scoped_insert on public.exams for insert to authenticated with check((select private.can_access_subject(subject_id)));
create policy exams_scoped_update on public.exams for update to authenticated using((select private.can_access_subject(subject_id))) with check((select private.can_access_subject(subject_id)));
create policy exams_scoped_delete on public.exams for delete to authenticated using((select private.can_access_subject(subject_id)));
drop policy if exists exam_questions_read on public.exam_questions;drop policy if exists exam_questions_staff on public.exam_questions;
create policy exam_questions_scoped_read on public.exam_questions for select to authenticated using(exists(select 1 from public.exams e where e.id=exam_id and (((select private.current_app_role())='student' and e.status='published') or (select private.can_access_subject(e.subject_id)))));
create policy exam_questions_scoped_insert on public.exam_questions for insert to authenticated with check(exists(select 1 from public.exams e where e.id=exam_id and (select private.can_access_subject(e.subject_id))));
create policy exam_questions_scoped_update on public.exam_questions for update to authenticated using(exists(select 1 from public.exams e where e.id=exam_id and (select private.can_access_subject(e.subject_id)))) with check(exists(select 1 from public.exams e where e.id=exam_id and (select private.can_access_subject(e.subject_id))));
create policy exam_questions_scoped_delete on public.exam_questions for delete to authenticated using(exists(select 1 from public.exams e where e.id=exam_id and (select private.can_access_subject(e.subject_id))));

drop policy if exists attempts_own_read on public.attempts;
create policy attempts_scoped_read on public.attempts for select to authenticated using(student_id=(select auth.uid()) or exists(select 1 from public.exams e where e.id=exam_id and (select private.can_access_subject(e.subject_id))));
drop policy if exists responses_own_read on public.responses;
create policy responses_scoped_read on public.responses for select to authenticated using(exists(select 1 from public.attempts a join public.exams e on e.id=a.exam_id where a.id=attempt_id and (a.student_id=(select auth.uid()) or (select private.can_access_subject(e.subject_id)))));
drop policy if exists violations_read on public.violations;
create policy violations_scoped_read on public.violations for select to authenticated using(exists(select 1 from public.attempts a join public.exams e on e.id=a.exam_id where a.id=attempt_id and (a.student_id=(select auth.uid()) or (select private.can_access_subject(e.subject_id)))));

drop policy if exists resources_read on public.external_resources;drop policy if exists resources_staff on public.external_resources;
create policy resources_scoped_read on public.external_resources for select to authenticated using(active and (subject_id is null or (select private.current_app_role())='student' or (select private.can_access_subject(subject_id))));
create policy resources_scoped_insert on public.external_resources for insert to authenticated with check((select private.current_app_role()) in('admin','reviewer') or (select private.can_access_subject(subject_id)));
create policy resources_scoped_update on public.external_resources for update to authenticated using((select private.current_app_role()) in('admin','reviewer') or (select private.can_access_subject(subject_id))) with check((select private.current_app_role()) in('admin','reviewer') or (select private.can_access_subject(subject_id)));
create policy resources_scoped_delete on public.external_resources for delete to authenticated using((select private.current_app_role()) in('admin','reviewer') or (select private.can_access_subject(subject_id)));

insert into public.teacher_subjects(teacher_id,subject_id) select u.id,s.id from auth.users u cross join public.subjects s where(lower(u.email),s.code) in((lower('vokhacsanh@gmail.com'),'VATLI'),(lower('khacsu2010@gmail.com'),'TOAN'),(lower('apluslocninh@gmail.com'),'TIENGANH')) on conflict do nothing;
commit;
