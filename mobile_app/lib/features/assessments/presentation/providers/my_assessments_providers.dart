import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/my_assessment_model.dart';
import 'assessments_providers.dart';

/// The signed-in employee's own assessments (GET /assessments/my/). One
/// request per screen visit; Retry and pull-to-refresh re-run it through
/// ref.invalidate / ref.refresh, which never starts a second request while
/// one is already in flight.
final myAssessmentsProvider = FutureProvider.autoDispose<MyAssessments>(
  (ref) => ref.read(assessmentsDataSourceProvider).fetchMyAssessments(),
);
