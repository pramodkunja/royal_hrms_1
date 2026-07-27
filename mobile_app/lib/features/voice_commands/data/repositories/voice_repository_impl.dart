import '../../domain/entities/voice_result_entity.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/voice_remote_datasource.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  final VoiceRemoteDataSource _ds;
  VoiceRepositoryImpl(this._ds);

  @override
  Future<VoiceResultEntity> parse({
    required String transcript,
    String lang = 'en',
    double? latitude,
    double? longitude,
  }) =>
      _ds.parse(transcript: transcript, lang: lang, latitude: latitude, longitude: longitude);
}
