// Ports the Recruitment module's Email Log — the only email-logging feature
// that exists anywhere in the backend (backend/apps/recruitment/models.py
// CandidateEmail + CandidateEmailLogView, GET /api/recruitment/emails/).
// There is no general HRMS-wide email log; leave/WFH/expense/onboarding
// emails leave no queryable trace beyond server logs.
class CandidateEmailEntity {
  final int id;
  final String templateUsed;
  final String subject;
  final String toEmail;
  final String status; // 'sent' | 'failed' — the only two backend values
  final String sentByName;
  final String sentAt; // ISO datetime
  final int? candidateId;
  final String candidateName;
  final String candidatePosition;

  const CandidateEmailEntity({
    required this.id,
    this.templateUsed = '',
    required this.subject,
    required this.toEmail,
    required this.status,
    this.sentByName = '',
    required this.sentAt,
    this.candidateId,
    this.candidateName = '',
    this.candidatePosition = '',
  });

  bool get isSent => status == 'sent';
  bool get isFailed => status == 'failed';
}

// Page envelope for GET /recruitment/emails/ — matches the backend's
// {count, page, page_size, total_pages, results} shape (a plain Django
// Paginator, not DRF's — see CandidateEmailLogView.get). Kept local to this
// feature, matching this codebase's per-feature pagination type convention
// (see leave_entity.dart's LeaveRequestPageEntity).
class EmailLogPageEntity {
  final List<CandidateEmailEntity> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const EmailLogPageEntity({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory EmailLogPageEntity.empty() => const EmailLogPageEntity(
        results: [],
        count: 0,
        page: 1,
        pageSize: 20,
        totalPages: 1,
      );
}

// Accumulating "load more" state for the infinite-scroll list — unlike
// [EmailLogPageEntity] (one API page), this keeps every item loaded so far
// plus whether a background loadMore() fetch is in flight, mirroring
// leave_entity.dart's LeaveLoadMoreState.
class EmailLogLoadMoreState {
  final List<CandidateEmailEntity> items;
  final int page;
  final int totalPages;
  final int count;
  final bool loadingMore;

  const EmailLogLoadMoreState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    this.loadingMore = false,
  });

  bool get hasMore => page < totalPages;

  EmailLogLoadMoreState copyWith({
    List<CandidateEmailEntity>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? loadingMore,
  }) =>
      EmailLogLoadMoreState(
        items: items ?? this.items,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        count: count ?? this.count,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}
