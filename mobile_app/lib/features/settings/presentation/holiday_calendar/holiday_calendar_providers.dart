import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/holiday_remote_datasource.dart';
import '../../data/models/holiday_model.dart';

final holidayDataSourceProvider = Provider<HolidayRemoteDataSource>((ref) {
  return HolidayRemoteDataSource(ref.watch(dioProvider));
});

typedef HolidaysKey = ({int year, String? branchName});

// Keyed by (year, branchName) so switching year or the branch filter re-fetches
// from the real /api/leave/holidays/ endpoint; type/optional/search filters
// stay client-side (small dataset, matches the screen's existing snappy-filter
// UX) via HolidayCalendarScreen's own filtering logic.
final holidaysProvider = AsyncNotifierProvider.autoDispose
    .family<HolidaysNotifier, List<HolidayModel>, HolidaysKey>(HolidaysNotifier.new);

class HolidaysNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<HolidayModel>, HolidaysKey> {
  @override
  Future<List<HolidayModel>> build(HolidaysKey arg) {
    return ref.read(holidayDataSourceProvider).fetchHolidays(
          year: arg.year,
          branchName: arg.branchName,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> add(HolidayFormData form) async {
    try {
      final created = await ref.read(holidayDataSourceProvider).createHoliday(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit(String id, HolidayFormData form) async {
    try {
      final updated = await ref.read(holidayDataSourceProvider).updateHoliday(id, form);
      state = AsyncData((state.valueOrNull ?? []).map((h) => h.id == id ? updated : h).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> remove(String id) async {
    try {
      await ref.read(holidayDataSourceProvider).deleteHoliday(id);
      state = AsyncData((state.valueOrNull ?? []).where((h) => h.id != id).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> toggleActive(String id) async {
    final matches = (state.valueOrNull ?? []).where((h) => h.id == id);
    if (matches.isEmpty) return null;
    final current = matches.first;
    try {
      final updated = await ref.read(holidayDataSourceProvider).setActive(id, !current.isActive);
      state = AsyncData((state.valueOrNull ?? []).map((h) => h.id == id ? updated : h).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// Uses the shared parseDioException() from core/network/api_client.dart so
// backend validation text (e.g. "Holiday name cannot be empty.",
// "Permission denied.") reaches the user verbatim instead of a generic string.
String friendlyHolidayError(Object e) => _friendly(e);

String _friendly(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}
