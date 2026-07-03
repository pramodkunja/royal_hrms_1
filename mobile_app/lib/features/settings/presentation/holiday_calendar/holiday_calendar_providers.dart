import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/holiday_model.dart';

// The reference web screen (frontend/app/dashboard/settings/holiday-calendar/page.tsx)
// has no backend of its own — it holds a local seed array and simulates saves
// with a 400ms delay. This provider faithfully reproduces that same local-state
// behaviour (no Dio/API calls) rather than inventing a backend contract that
// doesn't exist yet.

final _kSeedHolidays = <HolidayModel>[
  HolidayModel(id: 1, name: "New Year's Day", date: DateTime(2025, 1, 1), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 2, name: 'Republic Day', date: DateTime(2025, 1, 26), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 3, name: 'Holi', date: DateTime(2025, 3, 14), type: HolidayType.national, isOptional: true, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 4, name: 'Good Friday', date: DateTime(2025, 4, 18), type: HolidayType.regional, isOptional: true, applicableBranches: 'Head Office, Mumbai', isActive: true),
  HolidayModel(id: 5, name: 'Independence Day', date: DateTime(2025, 8, 15), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 6, name: 'Ganesh Chaturthi', date: DateTime(2025, 8, 27), type: HolidayType.regional, isOptional: true, applicableBranches: 'Mumbai, Bengaluru', isActive: true),
  HolidayModel(id: 7, name: "Founders' Day", date: DateTime(2025, 11, 5), type: HolidayType.company, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 8, name: 'Gandhi Jayanti', date: DateTime(2025, 10, 2), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 9, name: 'Diwali', date: DateTime(2025, 10, 20), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 10, name: 'Christmas', date: DateTime(2025, 12, 25), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 11, name: "New Year's Day", date: DateTime(2026, 1, 1), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 12, name: 'Republic Day', date: DateTime(2026, 1, 26), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 13, name: 'Holi', date: DateTime(2026, 3, 4), type: HolidayType.national, isOptional: true, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 14, name: 'Annual Foundation Day', date: DateTime(2026, 7, 10), type: HolidayType.company, isOptional: true, applicableBranches: 'All', isActive: false),
  HolidayModel(id: 15, name: 'Independence Day', date: DateTime(2026, 8, 15), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 16, name: 'Onam', date: DateTime(2026, 8, 26), type: HolidayType.regional, isOptional: true, applicableBranches: 'Chennai, Bengaluru', isActive: true),
  HolidayModel(id: 17, name: 'Diwali', date: DateTime(2026, 11, 8), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
  HolidayModel(id: 18, name: 'Christmas', date: DateTime(2026, 12, 25), type: HolidayType.national, isOptional: false, applicableBranches: 'All', isActive: true),
];

final holidaysProvider =
    NotifierProvider<HolidaysNotifier, List<HolidayModel>>(HolidaysNotifier.new);

class HolidaysNotifier extends Notifier<List<HolidayModel>> {
  @override
  List<HolidayModel> build() => List.of(_kSeedHolidays);

  Future<void> add(HolidayFormData form) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final nextId = state.isEmpty ? 1 : state.map((h) => h.id).reduce((a, b) => a > b ? a : b) + 1;
    state = [
      ...state,
      HolidayModel(
        id: nextId,
        name: form.name.trim(),
        date: form.date!,
        type: form.type,
        isOptional: form.isOptional,
        applicableBranches: form.applicableBranches.trim().isEmpty ? 'All' : form.applicableBranches.trim(),
        isActive: form.isActive,
      ),
    ];
  }

  Future<void> edit(int id, HolidayFormData form) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    state = state.map((h) {
      if (h.id != id) return h;
      return h.copyWith(
        name: form.name.trim(),
        date: form.date,
        type: form.type,
        isOptional: form.isOptional,
        applicableBranches: form.applicableBranches.trim().isEmpty ? 'All' : form.applicableBranches.trim(),
        isActive: form.isActive,
      );
    }).toList();
  }

  void remove(int id) {
    state = state.where((h) => h.id != id).toList();
  }

  void toggleActive(int id) {
    state = state.map((h) => h.id == id ? h.copyWith(isActive: !h.isActive) : h).toList();
  }
}
