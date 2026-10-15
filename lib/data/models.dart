import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

Map<String, int> _intMap(dynamic m) => {
  for (final e in ((m as Map?) ?? const {}).entries)
    e.key as String: (e.value as num).toInt(),
};

class Room {
  const Room({
    required this.code,
    required this.name,
    required this.ownerId,
    required this.members,
    required this.period,
    required this.periodStart,
    required this.opening,
  });

  final String code;
  final String name;
  final String ownerId;
  final Map<String, String> members; // uid -> display name
  final int period;
  final DateTime periodStart;
  final Map<String, int> opening; // carried-forward balances (paisa)

  factory Room.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Room(
      code: d.id,
      name: (m['name'] as String?) ?? 'Room',
      ownerId: (m['ownerId'] as String?) ?? '',
      members: Map<String, String>.from((m['members'] as Map?) ?? const {}),
      period: (m['period'] as num?)?.toInt() ?? 1,
      periodStart: _ts(m['periodStart']),
      opening: _intMap(m['opening']),
    );
  }

  /// Member ids sorted by display name.
  List<String> get ids {
    final l = members.keys.toList();
    l.sort((a, b) => members[a]!.toLowerCase().compareTo(members[b]!.toLowerCase()));
    return l;
  }

  String nameOf(String uid) => members[uid] ?? 'Unknown';
}

class Expense {
  const Expense({
    this.id = '',
    required this.title,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.split,
    required this.date,
    required this.createdAt,
    required this.createdBy,
    required this.period,
    this.splitType = 'equal',
    this.shares = const {},
  });

  final String id;
  final String title;
  final int amount; // paisa
  final String category;
  final String paidBy;
  final List<String> split;
  final DateTime date;
  final DateTime createdAt;
  final String createdBy;
  final int period;

  /// 'equal' (default, split evenly among [split]) or 'custom' (exact [shares]).
  final String splitType;

  /// Custom mode only: uid -> exact share in paisa. Sum always equals [amount].
  final Map<String, int> shares;

  bool get isCustom => splitType == 'custom' && shares.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'title': title,
    'amount': amount,
    'category': category,
    'paidBy': paidBy,
    'split': split,
    'date': Timestamp.fromDate(date),
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'period': period,
    'splitType': splitType,
    'shares': shares,
  };

  factory Expense.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Expense(
      id: d.id,
      title: (m['title'] as String?) ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      category: (m['category'] as String?) ?? 'other',
      paidBy: (m['paidBy'] as String?) ?? '',
      split: List<String>.from((m['split'] as List?) ?? const []),
      date: _ts(m['date']),
      createdAt: _ts(m['createdAt']),
      createdBy: (m['createdBy'] as String?) ?? '',
      period: (m['period'] as num?)?.toInt() ?? 1,
      splitType: (m['splitType'] as String?) ?? 'equal',
      shares: _intMap(m['shares']),
    );
  }
}

/// A closed account (settled period).
class PeriodRecord {
  const PeriodRecord({
    required this.no,
    required this.start,
    required this.end,
    required this.total,
    required this.count,
    required this.balances,
  });

  final int no;
  final DateTime start;
  final DateTime end;
  final int total;
  final int count;
  final Map<String, int> balances;

  factory PeriodRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return PeriodRecord(
      no: (m['no'] as num?)?.toInt() ?? 0,
      start: _ts(m['start']),
      end: _ts(m['end']),
      total: (m['total'] as num?)?.toInt() ?? 0,
      count: (m['count'] as num?)?.toInt() ?? 0,
      balances: _intMap(m['balances']),
    );
  }
}