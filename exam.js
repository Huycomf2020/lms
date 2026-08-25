const config=window.LMS_CONFIG;
const questions=[
 {id:"q1",stem:"Cho hàm số f(x) = x³ − 3x. Giá trị của f'(2) bằng",options:["3","6","9","12"]},
 {id:"q2",stem:"Một lớp có 20 học sinh nam và 25 học sinh nữ. Chọn ngẫu nhiên một học sinh. Xác suất chọn được học sinh nữ là",options:["4/9","5/9","1/2","5/4"]},
 {id:"q3",stem:"Trong không gian Oxyz, khoảng cách từ điểm M(1; 2; 2) đến gốc tọa độ O bằng",options:["2","3","4","9"]},
 {id:"q4",stem:"Nghiệm của phương trình log₂(x) = 3 là",options:["6","8","9","12"]},
 {id:"q5",stem:"Cấp số cộng có u₁ = 2 và công sai d = 3. Giá trị u₅ bằng",options:["11","12","14","17"]}
];
let current=0,remaining=90*60,violations=0,started=false,lastViolation=0;
const answers={};
const token=sessionStorage.getItem("lms_access_token")||"";
const attemptId=crypto.randomUUID();

function render(){
 const q=questions[current];document.querySelector("#question-index").textContent=`Câu ${current+1}/${questions.length}`;document.querySelector("#question-stem").textContent=q.stem;
 document.querySelector("#options").innerHTML=q.options.map((x,i)=>`<button class="option ${answers[q.id]===i?"selected":""}" data-option="${i}"><b>${String.fromCharCode(65+i)}</b><span>${x}</span></button>`).join("");
 document.querySelectorAll("[data-option]").forEach(el=>el.onclick=()=>{answers[q.id]=Number(el.dataset.option);render();queueSave("response",{question_id:q.id,selected_option:answers[q.id]});});
 document.querySelector("#question-map").innerHTML=questions.map((x,i)=>`<button data-index="${i}" class="${i===current?"active":""} ${answers[x.id]!==undefined?"answered":""}">${i+1}</button>`).join("");
 document.querySelectorAll("[data-index]").forEach(el=>el.onclick=()=>{current=Number(el.dataset.index);render();});
}
function tick(){remaining--;const h=String(Math.floor(remaining/3600)).padStart(2,"0"),m=String(Math.floor(remaining%3600/60)).padStart(2,"0"),s=String(remaining%60).padStart(2,"0");document.querySelector("#timer").textContent=`${h}:${m}:${s}`;if(remaining<=0)finish();}
async function start(){
 started=true;document.querySelector("#exam-gate").classList.add("hidden");
 try{await document.documentElement.requestFullscreen();}catch(e){violate("Không thể vào chế độ toàn màn hình");}
 try{const stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:"user"},audio:false});document.querySelector("#camera").srcObject=stream;}catch(e){violate("Webcam bị từ chối hoặc không khả dụng");}
 setInterval(tick,1000);render();queueSave("start",{exam_id:new URLSearchParams(location.search).get("id")||"demo"});
}
function violate(message){
 if(!started)return;const now=Date.now();if(now-lastViolation<1200)return;lastViolation=now;violations++;document.querySelector("#violation-count").textContent=violations;document.querySelector("#warning-message").textContent=message;document.querySelector("#warning-dialog").showModal();queueSave("violation",{type:message,occurred_at:new Date().toISOString(),page_visibility:document.visibilityState});
}
async function queueSave(kind,payload){
 const event={attempt_id:attemptId,kind,payload,user_agent:navigator.userAgent,created_at:new Date().toISOString()};
 const queue=JSON.parse(localStorage.getItem("lms_event_queue")||"[]");queue.push(event);localStorage.setItem("lms_event_queue",JSON.stringify(queue.slice(-200)));
 if(!config.appsScriptUrl)return;
 try{await fetch(config.appsScriptUrl,{method:"POST",mode:"no-cors",headers:{"Content-Type":"text/plain"},body:JSON.stringify(event)});document.querySelector("#connection").textContent="● Đã lưu";}catch(e){document.querySelector("#connection").textContent="● Chờ đồng bộ";}
 if(token && kind==="violation"){
   fetch(`${config.supabaseUrl}/rest/v1/violations`,{method:"POST",headers:{apikey:config.supabasePublishableKey,Authorization:`Bearer ${token}`,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({attempt_id:attemptId,event_type:payload.type,details:payload})}).catch(()=>{});
 }
}
function finish(){queueSave("finish",{answers,remaining,violations});if(document.fullscreenElement)document.exitFullscreen().catch(()=>{});document.querySelector("#finish-dialog").showModal();}
document.querySelector("#consent").onchange=e=>document.querySelector("#start-exam").disabled=!e.target.checked;
document.querySelector("#start-exam").onclick=start;document.querySelector("#prev").onclick=()=>{current=Math.max(0,current-1);render();};document.querySelector("#next").onclick=()=>{current=Math.min(questions.length-1,current+1);render();};document.querySelector("#submit").onclick=finish;
document.querySelector("#return-exam").onclick=async()=>{document.querySelector("#warning-dialog").close();if(!document.fullscreenElement)try{await document.documentElement.requestFullscreen();}catch(e){}};
document.addEventListener("visibilitychange",()=>{if(document.hidden)violate("Rời khỏi màn hình làm bài hoặc chuyển ứng dụng");});
document.addEventListener("fullscreenchange",()=>{if(started&&!document.fullscreenElement)violate("Thoát chế độ toàn màn hình");});
document.addEventListener("contextmenu",e=>{e.preventDefault();violate("Sử dụng chuột phải");});
document.addEventListener("copy",e=>{e.preventDefault();violate("Sao chép nội dung đề thi");});
document.addEventListener("cut",e=>{e.preventDefault();violate("Cắt nội dung đề thi");});
document.addEventListener("keydown",e=>{if((e.ctrlKey||e.metaKey)&&["c","x","u","s","p"].includes(e.key.toLowerCase())){e.preventDefault();violate(`Sử dụng tổ hợp phím bị hạn chế (${e.key.toUpperCase()})`);}if(e.key==="PrintScreen")violate("Sử dụng phím chụp màn hình");});
window.addEventListener("beforeunload",e=>{if(started){e.preventDefault();e.returnValue="";}});
render();
