# AEEF ExamHub

Nền tảng LMS và thi thử TN THPT 2026, giao diện theo nhận diện AEEF.

## Thành phần

- `index.html`: trang tổng quan và hệ sinh thái học liệu.
- `exam.html`: phòng thi với fullscreen, webcam có đồng ý, cảnh báo và nhật ký sự kiện.
- `apps-script/Code.gs`: webhook ghi sự kiện vào Google Sheet `ExamEvents`.
- `supabase/migrations`: mô hình dữ liệu khảo thí và chính sách RLS.

## Triển khai GitHub Pages

Đưa các tệp ở thư mục gốc lên nhánh `main`, sau đó bật Pages từ `Settings → Pages → Deploy from a branch`.

## Apps Script

Sao chép `apps-script/Code.gs` vào Apps Script gắn với Google Sheet, triển khai lại Web app và cấp quyền chạy dưới tài khoản chủ sở hữu. Cột dữ liệu bắt đầu bằng ký tự công thức được vô hiệu hóa để tránh spreadsheet injection.

## Bảo mật

- `config.js` chỉ được chứa publishable key.
- Khóa AI và `service_role` phải nằm ở Edge Function hoặc dịch vụ máy chủ.
- Chặn sao chép/chụp màn hình trong web chỉ là biện pháp răn đe và ghi nhận, không phải DRM tuyệt đối.
- Webcam chỉ bật sau khi thí sinh đồng ý rõ ràng.
