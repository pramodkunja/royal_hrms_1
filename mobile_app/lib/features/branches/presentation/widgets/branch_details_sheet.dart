import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/branch_entity.dart';
import '../utils/branch_formatters.dart';
import 'branch_dlg_header.dart';

/// Full field dump for a branch — the safe place to expose everything the
/// API returns without crowding the card. Read-only.
Future<void> showBranchDetailsSheet(BuildContext context, BranchEntity b) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: AppColors.background,
          child: Column(
            children: [
              BranchDlgHeader(
                icon: Icons.business_outlined,
                title: b.branchName,
                subtitle: 'Branch Code: ${b.branchCode}',
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _Section(title: 'Identity', rows: [
                      _row('Branch Name', b.branchName),
                      _row('Branch Code', b.branchCode),
                      _row('Branch ID', '#${b.id}'),
                      _row('Headquarters', b.isHeadquarter ? 'Yes' : 'No'),
                      _row('Status', b.isActive ? 'Active' : 'Inactive'),
                    ]),
                    _Section(title: 'Location', rows: [
                      _row('City', b.cityName),
                      _row('State', b.stateName),
                      _row('Address', b.address.isEmpty ? 'Not available' : b.address),
                    ]),
                    _Section(title: 'Workforce & HR', rows: [
                      _row('Employees', b.employeesLabel),
                      _row('HR Manager', b.hasHr ? b.hrName! : 'Not Assigned'),
                    ]),
                    _Section(title: 'Geolocation & Attendance', rows: [
                      _row('Geofencing', b.geofencingEnabled ? 'Enabled' : 'Disabled'),
                      _row('Allowed Radius', '${b.allowedRadiusMeters} m'),
                      _row('Coordinates',
                          b.hasCoordinates ? 'Available' : 'Not Available'),
                      _row(
                        'Latitude / Longitude',
                        formatBranchCoordinates(
                          hasCoordinates: b.hasCoordinates,
                          latitude: b.latitude,
                          longitude: b.longitude,
                        ),
                      ),
                    ]),
                    _Section(title: 'Timeline', rows: [
                      _row('Created', formatBranchDateTime(b.createdAt)),
                      _row('Last Updated', formatBranchDateTime(b.updatedAt)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

_DetailRow _row(String label, String value) => _DetailRow(label, value);

class _Section extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(rows[i].label, style: AppTextStyles.bodySecondary),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        rows[i].value,
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
