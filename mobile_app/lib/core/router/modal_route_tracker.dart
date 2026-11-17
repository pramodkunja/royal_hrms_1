import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Knows whether any popup route — a dialog (incl. date/time pickers), a
/// modal bottom sheet, a popup menu or a dropdown menu — is open on any of
/// the app's navigators.
///
/// Why this exists (Task C1 / HO-02): the global voice-assistant overlay
/// (VoiceMicOverlay) is mounted in MaterialApp.router's `builder` Stack,
/// ABOVE the router's Navigator — so every dialog and sheet, which the
/// Navigator draws in its own Overlay, rendered underneath it, and the robot
/// took taps meant for them (e.g. a date picker's OK button started a
/// microphone recording instead). The overlay watches [isModalOpen] and gets
/// out of the way while any popup route is showing.
///
/// Each Navigator needs its own NavigatorObserver instance (an observer can
/// only be attached to one navigator at a time), so call [newObserver] once
/// per navigator — the root GoRouter and the dashboard ShellRoute.
class ModalRouteTracker extends ChangeNotifier {
  final Set<Route<dynamic>> _open = <Route<dynamic>>{};
  bool _disposed = false;

  bool get isModalOpen => _open.isNotEmpty;

  NavigatorObserver newObserver() => _ModalRouteObserver(this);

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute && _open.add(route)) _notify();
  }

  void _remove(Route<dynamic>? route) {
    if (route != null && _open.remove(route)) _notify();
  }

  // Navigator callbacks can arrive while a frame is being built (e.g. a
  // route pushed from didChangeDependencies); listeners rebuild widgets, so
  // defer the notification to after that frame instead of rebuilding
  // mid-build.
  void _notify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _ModalRouteObserver extends NavigatorObserver {
  _ModalRouteObserver(this._tracker);
  final ModalRouteTracker _tracker;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _tracker._add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _tracker._remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _tracker._remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _tracker._remove(oldRoute);
    _tracker._add(newRoute);
  }
}

/// One tracker for the whole app; the router attaches an observer per
/// navigator and the voice overlay watches it.
final modalRouteTrackerProvider = ChangeNotifierProvider<ModalRouteTracker>((ref) => ModalRouteTracker());
