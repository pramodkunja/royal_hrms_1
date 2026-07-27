import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/secure_storage.dart';

const _kDeviceIdKey = 'device_id';

/// A stable per-install identifier sent as `device_id` on attendance punches
/// (audit trail / anomaly detection on the backend). Generated once and
/// persisted in secure storage rather than read from the OS — avoids the
/// permission prompts and platform-channel dependency a real hardware
/// identifier (IMEI/androidId/identifierForVendor) would require, while
/// still letting the backend tell "same device" apart from "different
/// device" across punches.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final existing = await storage.read(_kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await storage.write(_kDeviceIdKey, id);
  return id;
});
