const config = window.LMS_CONFIG;
const fallbackExams = [
  {id:"demo-toan",subject:"TOÁN",title:"Đề thi thử Toán · Mã 0101",duration_minutes:90,question_count:34,status:"Sẵn sàng"},
  {id:"demo-van",subject:"NGỮ VĂN",title:"Đề thi thử Ngữ văn · Mã 0201",duration_minutes:120,question_count:2,status:"Sắp mở"},
  {id:"demo-anh",subject:"TIẾNG ANH",title:"Đề thi thử Tiếng Anh · Mã 0301",duration_minutes:60,question_count:40,status:"Sẵn sàng"}
];

const state = { accessToken: sessionStorage.getItem("lms_access_token") || "" };
const apiHeaders = () => ({apikey:config.supabasePublishableKey,Authorization:`Bearer ${state.accessToken || config.supabasePublishableKey}`});

async function loadExams(){
  let exams = fallbackExams;
  try{
    const res = await fetch(`${config.supabaseUrl}/rest/v1/exams?select=id,title,duration_minutes,status,subjects(name)&status=eq.published&order=created_at.desc`,{headers:apiHeaders()});
    if(res.ok){const rows=await res.json();if(rows.length)exams=rows.map(x=>({...x,subject:x.subjects?.name||"KỲ THI",question_count:"—"}));}
  }catch(error){console.info("Đang dùng dữ liệu minh họa.");}
  document.querySelector("#exam-grid").innerHTML=exams.map(exam=>`<article class="exam-card"><span class="tag">${exam.status}</span><h3>${exam.title}</h3><p class="muted">Mô phỏng cấu trúc thi, lưu bài định kỳ và ghi nhận sự kiện giám sát.</p><div class="exam-meta"><span>◷ ${exam.duration_minutes} phút</span><span>▤ ${exam.question_count} câu</span><span>${exam.subject}</span></div><a class="button primary" href="exam.html?id=${encodeURIComponent(exam.id)}">Vào phòng thi</a></article>`).join("");
}

async function login(){
  const email=document.querySelector("#email").value.trim(), password=document.querySelector("#password").value;
  const msg=document.querySelector("#auth-message");
  msg.textContent="Đang xác thực…";
  try{
    const res=await fetch(`${config.supabaseUrl}/auth/v1/token?grant_type=password`,{method:"POST",headers:{apikey:config.supabasePublishableKey,"Content-Type":"application/json"},body:JSON.stringify({email,password})});
    const data=await res.json();
    if(!res.ok)throw new Error(data.msg||data.error_description||"Không thể đăng nhập");
    state.accessToken=data.access_token;sessionStorage.setItem("lms_access_token",data.access_token);
    document.querySelector("#auth-label").textContent=email;document.querySelector("#auth-modal").close();
  }catch(err){msg.textContent=err.message;}
}

document.querySelector("#mobile-menu").addEventListener("click",()=>document.querySelector("#top-nav").classList.toggle("open"));
document.querySelector("#auth-button").addEventListener("click",()=>document.querySelector("#auth-modal").showModal());
document.querySelector("#login-button").addEventListener("click",login);
document.querySelectorAll("[data-open-modal]").forEach(el=>el.addEventListener("click",()=>document.querySelector(`#${el.dataset.openModal}`).showModal()));
loadExams();
