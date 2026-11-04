import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../router/access_control.dart';

/// Whether the signed-in user holds [codename] — for showing or hiding an
/// action button (web: hooks/usePermission.ts).
///
/// Reads the permissions the server sent with the signed-in user (login and
/// profile refresh) through [userHasPermission], the same rule the router
/// and menu use (backend core/permissions.py has_perm: superuser or
/// settings.edit passes everything). No user, or auth still loading or
/// failed, holds nothing. Rebuilds whenever the signed-in user changes.
///
/// UI only: the backend still checks every request, and screens show its
/// refusal if one comes back.
final permissionProvider = Provider.autoDispose.family<bool, String>(
  (ref, codename) => userHasPermission(ref.watch(authStateProvider).valueOrNull?.user, codename),
);
