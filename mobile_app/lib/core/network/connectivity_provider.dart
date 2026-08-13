import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Online/offline state, seeded with a one-shot check (so the app doesn't
/// briefly assume "online" before the first stream event) and then followed
/// by connectivity_plus's change stream for the rest of the app's lifetime.
///
/// This reports link-layer reachability (Wi-Fi/cellular association) rather
/// than confirmed internet access — good enough to drive the global
/// "no internet" overlay without a per-request probe.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  yield _isOnline(await Connectivity().checkConnectivity());
  yield* Connectivity().onConnectivityChanged.map(_isOnline);
});
