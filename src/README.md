# src/ — Mã nguồn Flutter

Thư mục này sẽ chứa **project Flutter** của ứng dụng.

## Chưa có gì ở đây
Project sẽ được khởi tạo ở **Giai đoạn 0** (xem `../plan/05-lo-trinh-phat-trien.md`) bằng lệnh:

```bash
# chạy tại thư mục src/
flutter create --platforms=windows,android,ios --org vn.canhsatbien .
```

Sau khi khởi tạo, cấu trúc `lib/` sẽ theo đúng thiết kế trong `../plan/03-kien-truc-ky-thuat.md`
(features: splash, search, lessons, translate, review, settings...).

## Điều kiện trước khi bắt đầu
- Đã cài Flutter SDK (stable) + bật Windows desktop (`flutter doctor`).
- Đã có `vocab.db` sinh từ PDF (do `../tools/` tạo) để nhúng vào `assets/db/`.
