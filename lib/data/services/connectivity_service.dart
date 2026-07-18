import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trạng thái mạng (có/không có kết nối) — đã chốt Q-CSB-06
/// (`docs/spec_history.md` [IMPL-013]) dùng `connectivity_plus`.
///
/// `true` = có ít nhất 1 kết nối mạng (wifi/di động/ethernet); không kiểm
/// tra API đích có phản hồi hay không (đó là việc của tầng gọi API riêng,
/// xem `02_Search.md` mục Online).
final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(_hasConnection);
});

bool _hasConnection(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
