import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/voice_remote_datasource.dart';
import '../../data/repositories/voice_repository_impl.dart';
import '../../domain/repositories/voice_repository.dart';

final voiceRemoteDataSourceProvider = Provider<VoiceRemoteDataSource>(
  (ref) => VoiceRemoteDataSource(ref.watch(dioProvider)),
);

final voiceRepositoryProvider = Provider<VoiceRepository>(
  (ref) => VoiceRepositoryImpl(ref.watch(voiceRemoteDataSourceProvider)),
);
