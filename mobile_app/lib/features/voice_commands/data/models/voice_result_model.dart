import '../../domain/entities/voice_result_entity.dart';

class VoiceResultModel extends VoiceResultEntity {
  const VoiceResultModel({
    required super.intent,
    required super.confidence,
    required super.result,
    required super.message,
    required super.conversational,
    required super.awaitingInput,
    required super.success,
  });

  // json is the inner `data` object of the response envelope — i.e.
  // envelope['data'], NOT the envelope itself. See conversation.py's
  // _payload(): the per-intent payload lives at data['result'], not
  // directly on data.
  factory VoiceResultModel.fromJson(Map<String, dynamic> json) {
    return VoiceResultModel(
      intent: json['intent'] as String? ?? 'no_match',
      confidence: (json['confidence'] as num?)?.toDouble(),
      result: json['result'],
      message: json['message'] as String? ?? '',
      conversational: json['conversational'] as bool? ?? false,
      awaitingInput: json['awaiting_input'] as bool? ?? false,
      success: json['success'] as bool? ?? true,
    );
  }
}
