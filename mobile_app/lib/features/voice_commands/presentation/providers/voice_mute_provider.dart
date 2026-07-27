import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/secure_storage.dart';

const _kVoiceMutedKey = 'voice_is_muted';

/// Whether spoken (TTS) confirmations are muted — same secure-storage-backed
/// toggle pattern as core/theme/theme_mode_provider.dart. Unlike the theme
/// flag, nothing needs this loaded before the first frame (there's no visual
/// flash to avoid), so the persisted value is loaded lazily on first read
/// instead of being threaded through main.dart.
final voiceMutedProvider = NotifierProvider<VoiceMutedNotifier, bool>(
  VoiceMutedNotifier.new,
);

class VoiceMutedNotifier extends Notifier<bool> {
  SecureStorageService get _storage => ref.read(secureStorageProvider);

  @override
  bool build() {
    _loadPersisted();
    return false;
  }

  Future<void> _loadPersisted() async {
    final saved = await _storage.read(_kVoiceMutedKey);
    if (saved != null) state = saved == 'true';
  }

  Future<void> toggle() => setMuted(!state);

  Future<void> setMuted(bool muted) async {
    state = muted;
    await _storage.write(_kVoiceMutedKey, muted.toString());
  }
}
