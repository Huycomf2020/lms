create or replace function public.create_exam_with_questions(
  p_blueprint_id uuid,
  p_title text,
  p_duration_minutes integer,
  p_question_ids uuid[],
  p_points numeric default 0.25
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_subject_id uuid;
  v_exam_id uuid;
  v_valid_count integer;
begin
  if not (select private.is_staff()) then
    raise exception 'Only staff can create exams';
  end if;
  if nullif(btrim(p_title), '') is null then raise exception 'Exam title is required'; end if;
  if p_duration_minutes <= 0 then raise exception 'Duration must be positive'; end if;
  if p_points <= 0 then raise exception 'Points must be positive'; end if;
  if coalesce(cardinality(p_question_ids), 0) = 0 then raise exception 'At least one question is required'; end if;
  if cardinality(p_question_ids) <> (select count(distinct question_id) from unnest(p_question_ids) as q(question_id)) then
    raise exception 'Question list contains duplicates';
  end if;

  select subject_id into v_subject_id
  from public.blueprints
  where id = p_blueprint_id and status = 'published';
  if v_subject_id is null then raise exception 'Published blueprint not found'; end if;

  select count(*) into v_valid_count
  from public.question_items
  where id = any(p_question_ids)
    and subject_id = v_subject_id
    and status = 'approved';
  if v_valid_count <> cardinality(p_question_ids) then
    raise exception 'Every question must be approved and belong to the blueprint subject';
  end if;

  insert into public.exams(subject_id, blueprint_id, title, duration_minutes, status, created_by)
  values(v_subject_id, p_blueprint_id, btrim(p_title), p_duration_minutes, 'draft', (select auth.uid()))
  returning id into v_exam_id;

  insert into public.exam_questions(exam_id, question_id, position, points)
  select v_exam_id, question_id, position::integer, p_points
  from unnest(p_question_ids) with ordinality as selected(question_id, position);

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values((select auth.uid()), 'create_exam', 'exam', v_exam_id::text,
    jsonb_build_object('blueprint_id', p_blueprint_id, 'question_count', cardinality(p_question_ids)));
  return v_exam_id;
end;
$$;

revoke all on function public.create_exam_with_questions(uuid,text,integer,uuid[],numeric) from public;
revoke execute on function public.create_exam_with_questions(uuid,text,integer,uuid[],numeric) from anon;
grant execute on function public.create_exam_with_questions(uuid,text,integer,uuid[],numeric) to authenticated;
