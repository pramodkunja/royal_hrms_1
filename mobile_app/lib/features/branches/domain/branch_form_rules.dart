import 'entities/branch_entity.dart';

// Add / Edit Branch rules, as web
// app/dashboard/branches/_components/BranchManagement.tsx (validate,
// BRANCH_NAME_RE, handleSave's hqConfirm) — identical for Add and Edit. The
// backend (apps/branch/serializers.py BranchSerializer.validate_branch_name)
// enforces the same pattern, length and messages on the trimmed value; it has
// no duplicate-name rule (only branch_code is unique), so neither does this.

/// Web BRANCH_NAME_RE (= backend _BRANCH_NAME_RE): starts and ends with a
/// letter or digit; in between letters, digits, spaces, `&`, `-` and `.`.
/// ASCII letters only, either case.
final kBranchNameRe = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9 &\-.]*[A-Za-z0-9])?$');

/// Web validate() for branch_name, on the trimmed value. Returns null when
/// valid. 200 characters is allowed ("under 200" is web's wording for > 200).
String? validateBranchName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'Branch name is required.';
  if (name.length > 200) return 'Branch name must be under 200 characters.';
  if (!kBranchNameRe.hasMatch(name)) {
    return 'Branch name may only contain letters, numbers, spaces, & - and . characters.';
  }
  return null;
}

/// Web handleSave: the "Change Headquarter?" confirm is needed when this
/// branch is being saved as headquarter and ANOTHER branch in the loaded list
/// already is. [editingId] is the branch being edited (null on Add).
BranchEntity? otherHeadquarter(List<BranchEntity> branches, {required bool markingHq, int? editingId}) {
  if (!markingHq) return null;
  return branches.where((b) => b.isHeadquarter && b.id != editingId).firstOrNull;
}

const kChangeHqTitle = 'Change Headquarter?';
const kChangeHqBody = 'Another branch is already marked as the headquarter. Setting this branch as HQ will remove the '
    'HQ status from the existing one. Do you want to continue?';
const kChangeHqConfirm = 'Yes, Change HQ';
