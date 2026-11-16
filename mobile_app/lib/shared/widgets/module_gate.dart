import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/access_control.dart' show userHasModule;
import '../../features/auth/presentation/providers/auth_providers.dart';

/// Shows [child] only when the company's subscription includes [module]
/// (web `hasModule(session.modules, key) && <Widget />`); an unknown module
/// list shows it. When hidden, [child] is never built, so it fetches nothing.
class ModuleGate extends ConsumerWidget {
  const ModuleGate({super.key, required this.module, required this.child});

  final String module;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      userHasModule(ref.watch(authStateProvider).valueOrNull?.user, module) ? child : const SizedBox.shrink();
}
