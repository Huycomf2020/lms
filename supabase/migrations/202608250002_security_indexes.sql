-- Khóa hàm quản trị tồn tại sẵn, không cho gọi từ Data API.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

-- Chỉ mục cho các khóa ngoại thường xuyên dùng trong RLS và báo cáo.
create index if not exists audit_logs_actor_id_idx on public.audit_logs(actor_id);
create index if not exists blueprints_subject_id_idx on public.blueprints(subject_id);
create index if not exists exam_questions_question_id_idx on public.exam_questions(question_id);
create index if not exists exams_blueprint_id_idx on public.exams(blueprint_id);
create index if not exists exams_created_by_idx on public.exams(created_by);
create index if not exists item_reviews_question_id_idx on public.item_reviews(question_id);
create index if not exists item_reviews_reviewer_id_idx on public.item_reviews(reviewer_id);
create index if not exists question_items_approved_by_idx on public.question_items(approved_by);
create index if not exists question_items_created_by_idx on public.question_items(created_by);
create index if not exists responses_question_id_idx on public.responses(question_id);
