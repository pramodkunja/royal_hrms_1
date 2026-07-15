import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/hrms_remote_datasource.dart';
import '../../domain/entities/birthday_entity.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final hrmsDataSourceProvider = Provider<HrmsRemoteDataSource>((ref) {
  return HrmsRemoteDataSource(ref.watch(dioProvider));
});

// ── Birthdays ─────────────────────────────────────────────────────────────────

// Read-only, no mutation — a FutureProvider is enough (no need for the
// AsyncNotifier ceremony used by features with write actions).
final birthdaysProvider = FutureProvider.autoDispose<BirthdaysResult>((ref) {
  return ref.read(hrmsDataSourceProvider).fetchBirthdays();
});

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyHrmsError(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('403')) return 'You do not have permission to view this.';
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('404')) return 'Birthdays could not be loaded right now.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return 'Something went wrong loading birthdays. Please try again.';
}
