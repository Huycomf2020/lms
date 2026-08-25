insert into public.blueprints(subject_id,name,year,specification,status)
select id,'Ma trận thi thử Toán TN THPT 2026',2026,'{"parts":[{"name":"Trắc nghiệm nhiều lựa chọn","questions":12},{"name":"Đúng/Sai","questions":4},{"name":"Trả lời ngắn","questions":6}],"version":"pilot-2026"}'::jsonb,'published' from public.subjects where code='TOAN'
on conflict do nothing;

insert into public.blueprints(subject_id,name,year,specification,status)
select id,'Ma trận thi thử Ngữ văn TN THPT 2026',2026,'{"parts":[{"name":"Đọc hiểu","points":4},{"name":"Viết","points":6}],"version":"pilot-2026"}'::jsonb,'published' from public.subjects where code='NGUVAN'
on conflict do nothing;

insert into public.blueprints(subject_id,name,year,specification,status)
select id,'Ma trận thi thử Tiếng Anh TN THPT 2026',2026,'{"parts":[{"name":"Trắc nghiệm","questions":40}],"version":"pilot-2026"}'::jsonb,'published' from public.subjects where code='TIENGANH'
on conflict do nothing;

insert into public.exams(subject_id,blueprint_id,title,duration_minutes,status)
select b.subject_id,b.id,'Đề thi thử Toán · Mã 0101',90,'published' from public.blueprints b where b.name='Ma trận thi thử Toán TN THPT 2026' and not exists(select 1 from public.exams where title='Đề thi thử Toán · Mã 0101');
insert into public.exams(subject_id,blueprint_id,title,duration_minutes,status)
select b.subject_id,b.id,'Đề thi thử Ngữ văn · Mã 0201',120,'published' from public.blueprints b where b.name='Ma trận thi thử Ngữ văn TN THPT 2026' and not exists(select 1 from public.exams where title='Đề thi thử Ngữ văn · Mã 0201');
insert into public.exams(subject_id,blueprint_id,title,duration_minutes,status)
select b.subject_id,b.id,'Đề thi thử Tiếng Anh · Mã 0301',50,'published' from public.blueprints b where b.name='Ma trận thi thử Tiếng Anh TN THPT 2026' and not exists(select 1 from public.exams where title='Đề thi thử Tiếng Anh · Mã 0301');
