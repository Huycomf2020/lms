with s as (select id from public.subjects where code='TOAN')
insert into public.question_items(subject_id,code,stem,options,item_type,topic,cognitive_level,difficulty_target,status)
select s.id,v.code,v.stem,v.options::jsonb,'single_choice',v.topic,v.level,v.difficulty,'approved'::public.item_status from s cross join (values
('TOAN-2026-001','Cho hàm số f(x) = x³ − 3x. Giá trị của f''(2) bằng','["3","6","9","12"]','Đạo hàm','recognition',0.75),
('TOAN-2026-002','Một lớp có 20 học sinh nam và 25 học sinh nữ. Chọn ngẫu nhiên một học sinh. Xác suất chọn được học sinh nữ là','["4/9","5/9","1/2","5/4"]','Xác suất','comprehension',0.65),
('TOAN-2026-003','Trong không gian Oxyz, khoảng cách từ điểm M(1; 2; 2) đến gốc tọa độ O bằng','["2","3","4","9"]','Hình học Oxyz','recognition',0.72),
('TOAN-2026-004','Nghiệm của phương trình log₂(x) = 3 là','["6","8","9","12"]','Mũ và logarit','recognition',0.80),
('TOAN-2026-005','Cấp số cộng có u₁ = 2 và công sai d = 3. Giá trị u₅ bằng','["11","12","14","17"]','Dãy số','comprehension',0.68)
) as v(code,stem,options,topic,level,difficulty)
on conflict(code) do update set stem=excluded.stem,options=excluded.options,topic=excluded.topic,cognitive_level=excluded.cognitive_level,difficulty_target=excluded.difficulty_target,status='approved',version=public.question_items.version+1,updated_at=now();

insert into public.question_keys(question_id,correct_answer,explanation)
select q.id,to_jsonb(v.answer),v.explanation from public.question_items q join (values
('TOAN-2026-001',2,'f''(x)=3x²−3 nên f''(2)=9.'),('TOAN-2026-002',1,'Có 25 học sinh nữ trên tổng số 45 học sinh, xác suất bằng 25/45=5/9.'),('TOAN-2026-003',1,'OM=√(1²+2²+2²)=3.'),('TOAN-2026-004',1,'x=2³=8.'),('TOAN-2026-005',2,'u₅=u₁+4d=2+12=14.')
) as v(code,answer,explanation) on q.code=v.code
on conflict(question_id) do update set correct_answer=excluded.correct_answer,explanation=excluded.explanation,updated_at=now();

insert into public.exam_questions(exam_id,question_id,position,points)
select e.id,q.id,row_number() over(order by q.code),2 from public.exams e join public.subjects s on s.id=e.subject_id and s.code='TOAN' cross join public.question_items q where e.title='Đề thi thử Toán · Mã 0101' and q.code like 'TOAN-2026-%'
on conflict(exam_id,question_id) do update set position=excluded.position,points=excluded.points;
