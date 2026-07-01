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
  final String id;
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
    required this.id,
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
      id:           json['id']            as String? ?? '',
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

class ExpenseStats {
  final int    total;
  final int    pending;
  final int    approved;
  final int    rejected;
  final double totalAmount;
  final double pendingAmount;
  final double approvedAmount;

  const ExpenseStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.totalAmount,
    required this.pendingAmount,
    required this.approvedAmount,
  });

  factory ExpenseStats.fromJson(Map<String, dynamic> json) => ExpenseStats(
    total:          _int(json['total']),
    pending:        _int(json['pending']),
    approved:       _int(json['approved']),
    rejected:       _int(json['rejected']),
    totalAmount:    _dbl(json['total_amount']),
    pendingAmount:  _dbl(json['pending_amount']),
    approvedAmount: _dbl(json['approved_amount']),
  );

  // Django's Sum() returns null when there are no rows and Decimal when
  // there are, both of which the standard cast fails on.
  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _dbl(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory ExpenseStats.empty() => const ExpenseStats(
    total: 0, pending: 0, approved: 0, rejected: 0,
    totalAmount: 0, pendingAmount: 0, approvedAmount: 0,
  );
}
