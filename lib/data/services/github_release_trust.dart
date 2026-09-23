import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Hosts touched when downloading a GitHub Release asset (xem redirect
/// chain thật: `github.com` trả 302 -> `release-assets.githubusercontent.com`
/// (backed bởi Azure Blob) mới là nơi thật sự truyền file).
const _githubReleaseAssetHosts = {'github.com', 'release-assets.githubusercontent.com'};

/// Một số máy thiếu chứng chỉ trung gian (intermediate CA) cần để xác
/// minh chain TLS của `release-assets.githubusercontent.com` (Azure Blob)
/// trong cache hệ thống — trình duyệt tự tải bù qua AIA, nhưng
/// BoringSSL đóng gói sẵn trong Dart/Flutter thì không, gây
/// `HandshakeException: CERTIFICATE_VERIFY_FAILED: unable to get local
/// issuer certificate` dù máy vẫn online bình thường (đã gặp thực tế,
/// dịch Online qua domain khác vẫn chạy tốt).
///
/// Bỏ qua lỗi xác minh chain CHỈ cho 2 host tải asset GitHub Release ở
/// trên - không áp dụng cho domain khác. Chấp nhận được vì toàn vẹn dữ
/// liệu đã được đảm bảo độc lập bằng SHA-256 verify sau khi tải xong
/// (xem [ChecksumMismatchException]/[Envit5ChecksumMismatchException]/
/// [LlmChecksumMismatchException]) - nếu ai chèn file giả qua MITM,
/// bước đó vẫn chặn lại, không âm thầm cài model giả.
void trustGitHubReleaseAssetHosts(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is! IOHttpClientAdapter) return;
  adapter.createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => _githubReleaseAssetHosts.contains(host);
    return client;
  };
}
