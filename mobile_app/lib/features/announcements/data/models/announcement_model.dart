import 'package:flutter/foundation.dart';

// ── Read model ─────────────────────────────────────────────────────────────────

@immutable
class AnnouncementModel {
  final String id;   // UUID primary key
  final String title;
  final String body;
  final String category;
  final String visibility;
  final int? targetDepartment;
  final int? targetBranch;
  final String? targetDepartmentName;
  final String? targetBranchName;
  final bool isPinned;
  final bool sendEmail;
  final String? postedBy;  // UUID FK to User
  final String postedByName;
  final String postedByRole;
  final int viewsCount;
  final int reactionsCount;
  final bool hasReacted;
  final bool canEdit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.visibility,
    this.targetDepartment,
    this.targetBranch,
    this.targetDepartmentName,
    this.targetBranchName,
    required this.isPinned,
    required this.sendEmail,
    this.postedBy,
    required this.postedByName,
    required this.postedByRole,
    required this.viewsCount,
    required this.reactionsCount,
    required this.hasReacted,
    required this.canEdit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? raw) {
      if (raw is String && raw.isNotEmpty) {
        return DateTime.tryParse(raw) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AnnouncementModel(
      id:                   json['id']?.toString() ?? '',
      title:                json['title'] as String? ?? '',
      body:                 json['body'] as String? ?? '',
      category:             json['category'] as String? ?? 'general',
      visibility:           json['visibility'] as String? ?? 'all',
      targetDepartment:     json['target_department'] as int?,
      targetBranch:         json['target_branch'] as int?,
      targetDepartmentName: json['target_department_name'] as String?,
      targetBranchName:     json['target_branch_name'] as String?,
      isPinned:             json['is_pinned'] as bool? ?? false,
      sendEmail:            json['send_email'] as bool? ?? false,
      postedBy:             json['posted_by']?.toString(),
      postedByName:         json['posted_by_name'] as String? ?? 'Unknown',
      postedByRole:         json['posted_by_role'] as String? ?? '',
      viewsCount:           json['views_count'] as int? ?? 0,
      reactionsCount:       json['reactions_count'] as int? ?? 0,
      hasReacted:           json['has_reacted'] as bool? ?? false,
      canEdit:              json['can_edit'] as bool? ?? false,
      createdAt:            parseDate(json['created_at']),
      updatedAt:            parseDate(json['updated_at']),
    );
  }

  AnnouncementModel copyWith({
    int? reactionsCount,
    bool? hasReacted,
    int? viewsCount,
  }) =>
      AnnouncementModel(
        id:                   id,
        title:                title,
        body:                 body,
        category:             category,
        visibility:           visibility,
        targetDepartment:     targetDepartment,
        targetBranch:         targetBranch,
        targetDepartmentName: targetDepartmentName,
        targetBranchName:     targetBranchName,
        isPinned:             isPinned,
        sendEmail:            sendEmail,
        postedBy:             postedBy,
        postedByName:         postedByName,
        postedByRole:         postedByRole,
        viewsCount:           viewsCount ?? this.viewsCount,
        reactionsCount:       reactionsCount ?? this.reactionsCount,
        hasReacted:           hasReacted ?? this.hasReacted,
        canEdit:              canEdit,
        createdAt:            createdAt,
        updatedAt:            updatedAt,
      );
}

// ── Stats ──────────────────────────────────────────────────────────────────────

@immutable
class AnnouncementStats {
  final int totalCount;
  final int pinnedCount;
  final int totalViews;
  final int totalReactions;

  const AnnouncementStats({
    required this.totalCount,
    required this.pinnedCount,
    required this.totalViews,
    required this.totalReactions,
  });

  factory AnnouncementStats.fromJson(Map<String, dynamic> json) => AnnouncementStats(
        totalCount:     json['count'] as int? ?? 0,
        pinnedCount:    json['pinned_count'] as int? ?? 0,
        totalViews:     json['total_views'] as int? ?? 0,
        totalReactions: json['total_reactions'] as int? ?? 0,
      );

  static const empty = AnnouncementStats(
    totalCount: 0, pinnedCount: 0, totalViews: 0, totalReactions: 0,
  );
}

// ── Page (list + stats + pagination) ─────────────────────────────────────────

@immutable
class AnnouncementPage {
  final List<AnnouncementModel> announcements;
  final AnnouncementStats stats;
  final int currentPage;
  final int totalPages;

  const AnnouncementPage({
    required this.announcements,
    required this.stats,
    required this.currentPage,
    required this.totalPages,
  });
}

// ── Form input ─────────────────────────────────────────────────────────────────

class AnnouncementFormData {
  String title;
  String body;
  String category;
  String visibility;
  int? targetDepartment;
  int? targetBranch;
  bool isPinned;
  bool sendEmail;

  AnnouncementFormData({
    this.title = '',
    this.body = '',
    this.category = 'general',
    this.visibility = 'all',
    this.targetDepartment,
    this.targetBranch,
    this.isPinned = false,
    this.sendEmail = false,
  });

  factory AnnouncementFormData.fromModel(AnnouncementModel model) =>
      AnnouncementFormData(
        title:            model.title,
        body:             model.body,
        category:         model.category,
        visibility:       model.visibility,
        targetDepartment: model.targetDepartment,
        targetBranch:     model.targetBranch,
        isPinned:         model.isPinned,
        sendEmail:        model.sendEmail,
      );

  Map<String, dynamic> toJson() => {
        'title':    title.trim(),
        'body':     body.trim(),
        'category': category,
        'visibility': visibility,
        if (visibility == 'department' && targetDepartment != null)
          'target_department': targetDepartment,
        if (visibility == 'branch' && targetBranch != null)
          'target_branch': targetBranch,
        'is_pinned':   isPinned,
        'send_email':  sendEmail,
      };

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (title.trim().isEmpty) errors['title'] = 'Title is required.';
    if (body.trim().isEmpty) errors['body'] = 'Body is required.';
    if (visibility == 'department' && targetDepartment == null) {
      errors['department'] = 'Select a target department.';
    }
    if (visibility == 'branch' && targetBranch == null) {
      errors['branch'] = 'Select a target branch.';
    }
    return errors;
  }
}

// ── Branch simple (for dropdown) ──────────────────────────────────────────────

@immutable
class BranchSimple {
  final int id;
  final String name;

  const BranchSimple({required this.id, required this.name});

  factory BranchSimple.fromJson(Map<String, dynamic> json) => BranchSimple(
        id:   json['id'] as int,
        name: json['branch_name'] as String? ?? '',
      );
}
