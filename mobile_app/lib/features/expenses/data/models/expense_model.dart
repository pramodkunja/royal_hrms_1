class ExpenseReceiptModel {
  final String id;
  final String? url;

  const ExpenseReceiptModel({required this.id, this.url});

  factory ExpenseReceiptModel.fromJson(Map<String, dynamic> json) =>
      ExpenseReceiptModel(
        id:  json['id']  as String? ?? '',
        url: json['url'] as String?,
      );
}

class ExpenseModel {
  // The backend's ExpenseSerializer never returns a UUID 'id' field — the
  // stable identifier callers must use for detail/approve routes is the
  // integer 'expense_number' (see apps/hrms/urls.py 'expenses/<int:expense_number>/').
  final int    expenseNumber;
  final String expenseRef;
  final String title;
  final String category;
  final double amount;
  final String expenseDate;
  final String description;
  final String status;
  final List<ExpenseReceiptModel> receipts;
  final String employeeName;
  final String branchName;
  final String createdAt;

  const ExpenseModel({
    required this.expenseNumber,
    required this.expenseRef,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.description,
    required this.status,
    required this.receipts,
    required this.employeeName,
    required this.branchName,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0;

    final rawReceipts = json['receipts'] as List<dynamic>? ?? [];
    return ExpenseModel(
      expenseNumber: (json['expense_number'] as num?)?.toInt() ?? 0,
      expenseRef:   json['expense_ref']     as String? ?? '',
      title:        json['title']         as String? ?? '',
      category:     json['category']      as String? ?? 'other',
      amount:       amount,
      expenseDate:  json['expense_date']  as String? ?? '',
      description:  json['description']   as String? ?? '',
      status:       json['status']        as String? ?? 'pending',
      receipts:     rawReceipts
          .map((e) => ExpenseReceiptModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      employeeName: json['employee_name'] as String? ?? '',
      branchName:   json['branch_name']   as String? ?? '',
      createdAt:    json['created_at']    as String? ?? '',
    );
  }
}

/// `GET /expenses/stats/` (backend `ExpenseStatsView`). Every field is nullable: a field the
/// server did not send, or sent as something that is not a number, is **unknown** (shown as
/// "—"), never silently 0 — a real 0 from the server stays 0.
///
/// Scope is the server's: a user with `expenses.approve` gets company-wide figures, everyone
/// else only their own claims. The values are not derived from the (paginated, category-filtered)
/// expense list.
class ExpenseStats {
  final int? total;
  final int? pending;
  final int? approved;
  final int? rejected;
  final double? totalAmount;
  final double? pendingAmount;
  final double? approvedAmount;

  const ExpenseStats({
    this.total,
    this.pending,
    this.approved,
    this.rejected,
    this.totalAmount,
    this.pendingAmount,
    this.approvedAmount,
  });

  factory ExpenseStats.fromJson(Map<String, dynamic> json) => ExpenseStats(
        total: _int(json['total']),
        pending: _int(json['pending']),
        approved: _int(json['approved']),
        rejected: _int(json['rejected']),
        totalAmount: _dbl(json['total_amount']),
        pendingAmount: _dbl(json['pending_amount']),
        approvedAmount: _dbl(json['approved_amount']),
      );

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num && v == v.truncate()) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // Amounts arrive as JSON numbers (the backend casts Decimal to float), but a string
  // decimal is accepted too.
  static double? _dbl(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
