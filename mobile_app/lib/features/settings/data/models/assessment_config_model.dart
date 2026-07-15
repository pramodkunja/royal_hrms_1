// Maps apps/assessments/serializers.py AssessmentSettingsSerializer exactly.
// Singleton global-defaults record (pk always 1 on the backend).

class AssessmentConfigModel {
  final int defaultPassPercentage; // 1-100
  final int maxAttempts; // >=0, 0 = unlimited
  final int? timeLimitMins; // >=1 or null = no global limit
  final String? updatedAt;

  const AssessmentConfigModel({
    required this.defaultPassPercentage,
    required this.maxAttempts,
    this.timeLimitMins,
    this.updatedAt,
  });

  static const defaults = AssessmentConfigModel(
    defaultPassPercentage: 70,
    maxAttempts: 3,
    timeLimitMins: null,
  );

  factory AssessmentConfigModel.fromJson(Map<String, dynamic> json) {
    return AssessmentConfigModel(
      defaultPassPercentage: (json['default_pass_percentage'] as num? ?? 70).toInt(),
      maxAttempts: (json['max_attempts'] as num? ?? 3).toInt(),
      timeLimitMins: (json['time_limit_mins'] as num?)?.toInt(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'default_pass_percentage': defaultPassPercentage,
        'max_attempts': maxAttempts,
        'time_limit_mins': timeLimitMins,
      };

  AssessmentConfigModel copyWith({
    int? defaultPassPercentage,
    int? maxAttempts,
    int? timeLimitMins,
    bool clearTimeLimit = false,
  }) =>
      AssessmentConfigModel(
        defaultPassPercentage: defaultPassPercentage ?? this.defaultPassPercentage,
        maxAttempts: maxAttempts ?? this.maxAttempts,
        timeLimitMins: clearTimeLimit ? null : (timeLimitMins ?? this.timeLimitMins),
        updatedAt: updatedAt,
      );
}
