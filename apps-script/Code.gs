/**
 * Webhook nhật ký thi. Gắn script này với Google Sheet đích.
 * Tạo sheet tên ExamEvents hoặc để hàm tự tạo.
 */
const SHEET_NAME = 'ExamEvents';

function doGet() {
  return json_({ ok: true, service: 'AEEF ExamHub event collector' });
}

function doPost(e) {
  try {
    const lock = LockService.getScriptLock();
    lock.waitLock(10000);
    try {
      const data = JSON.parse((e && e.postData && e.postData.contents) || '{}');
      const sheet = getEventSheet_();
      sheet.appendRow([
        new Date(),
        safe_(data.attempt_id),
        safe_(data.kind),
        safe_(data.payload && data.payload.type),
        JSON.stringify(data.payload || {}),
        safe_(data.user_agent),
        safe_(data.created_at)
      ]);
    } finally {
      lock.releaseLock();
    }
    return json_({ ok: true });
  } catch (error) {
    return json_({ ok: false, error: String(error) });
  }
}

function getEventSheet_() {
  const file = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = file.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = file.insertSheet(SHEET_NAME);
    sheet.appendRow(['ServerTime', 'AttemptID', 'EventType', 'ViolationType', 'Payload', 'UserAgent', 'ClientTime']);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function safe_(value) {
  const text = String(value == null ? '' : value);
  return /^[=+\-@]/.test(text) ? "'" + text : text;
}

function json_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(ContentService.MimeType.JSON);
}
