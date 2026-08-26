(() => {
  let staged = [];
  const $ = selector => document.querySelector(selector);
  const esc = value => String(value ?? "").replace(/[&<>'"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"}[c]));
  const msg = text => { $("#bulk-message").textContent = text; };
  const levelMap = {"nhận biết":"recognition","nhan biet":"recognition","recognition":"recognition","thông hiểu":"comprehension","thong hieu":"comprehension","comprehension":"comprehension","vận dụng":"application","van dung":"application","application":"application"};
  const cleanLevel = value => levelMap[String(value || "").trim().toLowerCase()] || "recognition";
  const answerLetter = value => String(value || "").trim().toUpperCase().match(/[A-D]/)?.[0] || "";

  function subjectCode() {
    return cache.subjects.find(x => x.id === $("#bulk-subject").value)?.code || "CAUHOI";
  }
  function normalize(row, index) {
    const options = Array.isArray(row.options) ? row.options : [row.A,row.B,row.C,row.D].filter(x => String(x || "").trim());
    return {
      code: String(row.code || `${$("#bulk-prefix").value.trim() || subjectCode()+"-2026"}-${String(index + 1).padStart(3,"0")}`).trim(),
      stem: String(row.stem || row["Nội dung"] || row["Câu hỏi"] || "").trim(),
      options: options.map(x => String(x).replace(/^[A-D][.\):]\s*/i,"").trim()).filter(Boolean),
      correct_answer: answerLetter(row.correct_answer || row.answer || row["Đáp án"]),
      topic: String(row.topic || row["Chủ đề"] || "").trim() || null,
      cognitive_level: cleanLevel(row.cognitive_level || row.level || row["Mức độ"])
    };
  }
  function validate(item, all) {
    const errors = [];
    if (!item.stem) errors.push("Thiếu nội dung");
    if (item.options.length < 2) errors.push("Thiếu phương án");
    if (!item.correct_answer || item.correct_answer.charCodeAt(0)-65 >= item.options.length) errors.push("Đáp án không hợp lệ");
    if (!item.code) errors.push("Thiếu mã");
    if (cache.questions.some(x => x.code.toLowerCase() === item.code.toLowerCase())) errors.push("Trùng mã trong ngân hàng");
    if (all.filter(x => x.code.toLowerCase() === item.code.toLowerCase()).length > 1) errors.push("Trùng mã trong tệp");
    return errors;
  }
  function stage(rows) {
    staged = rows.map(normalize).slice(0, 200);
    staged.forEach(x => x.errors = validate(x, staged));
    renderPreview();
    msg(staged.length ? "Đã phân tích xong. Hãy xem bảng kiểm định bên dưới." : "Không tìm thấy câu hỏi theo đúng cấu trúc.");
  }
  function renderPreview() {
    const valid = staged.filter(x => !x.errors.length).length;
    $("#import-preview").hidden = !staged.length;
    $("#preview-summary").innerHTML = `<span class="summary-chip">${staged.length} câu đã đọc</span><span class="summary-chip">${valid} câu hợp lệ</span>${valid < staged.length ? `<span class="summary-chip bad">${staged.length-valid} câu cần sửa</span>` : ""}`;
    $("#preview-body").innerHTML = staged.map((x,i) => `<tr><td>${i+1}</td><td><b>${esc(x.code)}</b></td><td>${esc(x.stem).slice(0,180)}</td><td>${x.options.length}</td><td>${esc(x.correct_answer || "—")}</td><td class="${x.errors.length?"check-bad":"check-ok"}">${x.errors.length ? esc(x.errors.join("; ")) : "✓ Hợp lệ"}</td></tr>`).join("");
    $("#save-bulk").disabled = !valid;
  }
  function parseText(text) {
    const parts = String(text).replace(/\r/g,"").split(/(?=^\s*(?:Câu|Question)\s*\d+\s*[.:])/gmi).filter(x => /(?:Câu|Question)\s*\d+/i.test(x));
    return parts.map(block => {
      const lines = block.split("\n").map(x=>x.trim()).filter(Boolean);
      const first = lines.shift() || "";
      const stemParts = [first.replace(/^\s*(?:Câu|Question)\s*\d+\s*[.:]\s*/i,"")];
      const options = []; let answer="",topic="",level="";
      lines.forEach(line => {
        const option = line.match(/^([A-D])[.\):]\s*(.+)$/i);
        const key = line.match(/^(?:Đáp án|Dap an|Answer)\s*:\s*(.+)$/i);
        const topicLine = line.match(/^(?:Chủ đề|Chu de|Topic)\s*:\s*(.+)$/i);
        const levelLine = line.match(/^(?:Mức độ|Muc do|Level)\s*:\s*(.+)$/i);
        if(option) options.push(option[2]); else if(key) answer=key[1]; else if(topicLine) topic=topicLine[1]; else if(levelLine) level=levelLine[1]; else stemParts.push(line);
      });
      return {stem:stemParts.join(" "),options,correct_answer:answer,topic,cognitive_level:level};
    });
  }
  function rowsFromSheet(data) {
    return data.map(row => ({code:row.code||row["Mã câu hỏi"]||row["Mã"],stem:row.stem||row["Nội dung"]||row["Câu hỏi"],A:row.A,B:row.B,C:row.C,D:row.D,correct_answer:row.correct_answer||row["Đáp án"],topic:row.topic||row["Chủ đề"],cognitive_level:row.cognitive_level||row["Mức độ"]}));
  }
  async function parseFile() {
    const file = $("#bulk-file").files[0];
    if (!file) return msg("Thầy vui lòng chọn một tệp.");
    if (file.size > 10*1024*1024) return msg("Tệp vượt quá giới hạn 10 MB.");
    msg("Đang đọc tệp…");
    try {
      const ext = file.name.split(".").pop().toLowerCase(); const buffer = await file.arrayBuffer();
      if (["xlsx","xls","csv"].includes(ext)) {
        const book = XLSX.read(buffer,{type:"array"}); stage(rowsFromSheet(XLSX.utils.sheet_to_json(book.Sheets[book.SheetNames[0]],{defval:""})));
      } else if (ext === "docx") {
        const result = await mammoth.extractRawText({arrayBuffer:buffer}); stage(parseText(result.value));
      } else if (ext === "pdf") {
        pdfjsLib.GlobalWorkerOptions.workerSrc="https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/build/pdf.worker.min.js";
        const pdf=await pdfjsLib.getDocument({data:buffer}).promise; let text="";
        for(let p=1;p<=pdf.numPages;p++){const page=await pdf.getPage(p),content=await page.getTextContent();text+=content.items.map(x=>x.str).join(" ")+"\n"}
        stage(parseText(text.replace(/\s+(Câu\s+\d+\s*[.:])/gi,"\n$1").replace(/\s+([A-D][.\):]\s+)/g,"\n$1").replace(/\s+(Đáp án\s*:)/gi,"\n$1")));
      } else stage(parseText(new TextDecoder("utf-8").decode(buffer)));
    } catch (error) { msg(`Không đọc được tệp: ${error.message}`); }
  }
  function aiPrompt() {
    const subject=cache.subjects.find(x=>x.id===$("#bulk-subject").value)?.name||"môn học",count=$("#ai-count").value,topic=$("#ai-topic").value||"ma trận TN THPT 2026",notes=$("#ai-notes").value;
    return `Bạn là chuyên gia ra đề thi tốt nghiệp THPT Việt Nam năm 2026. Hãy tạo ${count} câu hỏi môn ${subject}, phạm vi: ${topic}. ${notes}\nYêu cầu: chính xác khoa học; không sao chép nguyên văn đề có bản quyền; mỗi câu có đúng 4 phương án, chỉ 1 đáp án đúng; phân bố mức độ hợp lý; không đưa lời giải vào nội dung câu hỏi. Chỉ trả về một mảng JSON hợp lệ, không markdown, theo cấu trúc: [{"stem":"Nội dung","options":["A","B","C","D"],"correct_answer":"A","topic":"Chủ đề","cognitive_level":"recognition|comprehension|application","explanation":"Giải thích ngắn"}]. Tự kiểm tra đáp án trước khi trả về.`;
  }
  async function saveBulk() {
    let valid=staged.filter(x=>!x.errors.length); if(!valid.length)return;
    const button=$("#save-bulk"); button.disabled=true; msg(`Đang đối chiếu ${valid.length} câu với ngân hàng…`);
    try {
      const subjectId=$("#bulk-subject").value;
      const existing=await api(`question_items?subject_id=eq.${encodeURIComponent(subjectId)}&select=code,stem&limit=10000`);
      const usedCodes=new Set(existing.map(x=>x.code.toLowerCase()));
      const normalizeStem=value=>String(value||"").toLowerCase().replace(/\s+/g," ").trim();
      const usedStems=new Set(existing.map(x=>normalizeStem(x.stem)));
      const prefix=$("#bulk-prefix").value.trim()||`${subjectCode()}-2026`;
      let nextNumber=1,renumbered=0,duplicates=0;
      const nextCode=()=>{let code;do{code=`${prefix}-${String(nextNumber++).padStart(3,"0")}`}while(usedCodes.has(code.toLowerCase()));usedCodes.add(code.toLowerCase());return code};
      valid.forEach(item=>{
        if(usedStems.has(normalizeStem(item.stem))){item.errors=["Câu này đã có trong ngân hàng"];duplicates++;return}
        if(usedCodes.has(item.code.toLowerCase())){item.code=nextCode();renumbered++}else usedCodes.add(item.code.toLowerCase());
        usedStems.add(normalizeStem(item.stem));
      });
      valid=valid.filter(x=>!x.errors.length);renderPreview();
      if(!valid.length){msg(`Không lưu thêm: ${duplicates} câu đã tồn tại đầy đủ trong ngân hàng.`);return}
      msg(`Đang lưu ${valid.length} câu mới${renumbered?`; ${renumbered} mã trùng đã được cấp lại`:""}…`);
      const items=valid.map(x=>({subject_id:subjectId,code:x.code,stem:x.stem,options:x.options,cognitive_level:x.cognitive_level,topic:x.topic,status:"draft"}));
      const saved=await api("question_items",{method:"POST",headers:{Prefer:"return=representation"},body:JSON.stringify(items)});
      const keys=saved.map((x,i)=>({question_id:x.id,correct_answer:valid[i].correct_answer}));
      await api("question_keys",{method:"POST",headers:{Prefer:"return=minimal"},body:JSON.stringify(keys)});
      const subjectName=cache.subjects.find(x=>x.id===$("#bulk-subject").value)?.name;
      saved.reverse().forEach(x=>cache.questions.unshift({...x,subjects:{name:subjectName}}));
      msg(`Đã lưu ${saved.length} câu mới ở trạng thái bản nháp${duplicates?`; bỏ qua ${duplicates} câu đã có`:""}.`); staged=[]; $("#import-preview").hidden=true; render("questions");
    } catch(error) { const duplicate=String(error.message).includes("23505");msg(duplicate?"Có người vừa lưu cùng dải mã. Hãy bấm Lưu lại để hệ thống đối chiếu và cấp mã mới.":`Lưu chưa hoàn tất: ${error.message}`); } finally { button.disabled=false; }
  }
  function downloadTemplate() {
    const rows=[{"Mã câu hỏi":"TOAN-2026-001","Nội dung":"Cho hàm số...","A":"Phương án A","B":"Phương án B","C":"Phương án C","D":"Phương án D","Đáp án":"B","Chủ đề":"Đạo hàm","Mức độ":"Nhận biết"}];
    const sheet=XLSX.utils.json_to_sheet(rows),book=XLSX.utils.book_new(); XLSX.utils.book_append_sheet(book,sheet,"CauHoi"); XLSX.writeFile(book,"LMS-ExamHub-Mau-Nhap-Cau-Hoi.xlsx");
  }
  function openBulk() { fillSubjects(); $("#bulk-subject").innerHTML=$("#q-subject").innerHTML; const s=cache.subjects.find(x=>x.id===$("#bulk-subject").value); $("#bulk-prefix").value=`${s?.code||"CAUHOI"}-2026`; $("#bulk-modal").showModal(); }

  $("#new-item").onclick=openBulk; $("#new-single").onclick=()=>$("#question-modal").showModal();
  $("#bulk-subject").onchange=()=>{$("#bulk-prefix").value=`${subjectCode()}-2026`};
  document.querySelectorAll("[data-import-tab]").forEach(button=>button.onclick=()=>{document.querySelectorAll("[data-import-tab]").forEach(x=>x.classList.toggle("active",x===button));document.querySelectorAll("[data-import-pane]").forEach(x=>x.classList.toggle("active",x.dataset.importPane===button.dataset.importTab))});
  $("#parse-text").onclick=()=>stage(parseText($("#bulk-text").value)); $("#parse-file").onclick=parseFile; $("#download-template").onclick=downloadTemplate;
  $("#copy-ai-prompt").onclick=async()=>{try{await navigator.clipboard.writeText(aiPrompt());msg("Đã sao chép prompt chuẩn. Hãy dán vào công cụ AI thầy đang dùng.")}catch{msg("Trình duyệt không cho phép sao chép. Thầy có thể chọn và sao chép thủ công.")}};
  $("#parse-ai").onclick=()=>{try{let raw=$("#ai-output").value.trim();if(/^Bạn là chuyên gia/i.test(raw))throw new Error("Thầy đang dán prompt, chưa phải kết quả AI. Hãy gửi prompt cho AI rồi dán mảng JSON AI trả về vào đây.");raw=raw.replace(/^```(?:json)?|```$/gmi,"").trim();const start=raw.indexOf("["),end=raw.lastIndexOf("]");if(start>=0&&end>start)raw=raw.slice(start,end+1);const data=JSON.parse(raw);if(!Array.isArray(data))throw new Error("Kết quả phải là một mảng JSON");stage(data)}catch(error){msg(`JSON chưa đúng: ${error.message}`)}};
  $("#save-bulk").onclick=saveBulk;
})();
