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
    this.left = const [],
  });

  final String code;
  final String name;
  final String ownerId;
  final Map<String, String> members; // uid -> display name (includes members who left)
  final int period;
  final DateTime periodStart;
  final Map<String, int> opening; // carried-forward balances (paisa)
  final List<String> left; // uids who left the room (their balances stay on record)

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
      left: List<String>.from((m['left'] as List?) ?? const []),
    );
  }

  /// All known member ids (including who left), sorted by display name.
  List<String> get ids {
    final l = members.keys.toList();
    l.sort((a, b) => members[a]!.toLowerCase().compareTo(members[b]!.toLowerCase()));
    return l;
  }

  /// Members currently in the room.
  List<String> get activeIds => ids.where((i) => !left.contains(i)).toList();

  bool isLeft(String uid) => left.contains(uid);

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
  final String title; // note
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
  bool get isLend => category == 'lend';

  /// Exact share per person in paisa (remainder paisa handled deterministically,
  /// same rule as calc.dart).
  Map<String, int> get shareMap {
    if (isCustom) return Map<String, int>.from(shares);
    final s = [...split]..sort();
    if (s.isEmpty) return {};
    final base = amount ~/ s.length;
    var rem = amount - base * s.length;
    final out = <String, int>{};
    for (final id in s) {
      final extra = rem > 0 ? 1 : 0;
      rem -= extra;
      out[id] = base + extra;
    }
    return out;
  }

  /// Effect of this expense on [uid]'s balance: positive = gets, negative = owes.
  int impactOn(String uid) => (paidBy == uid ? amount : 0) - (shareMap[uid] ?? 0);

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

/// An approval request inside a room: leaving the room, or closing the account.
class RoomRequest {
  const RoomRequest({
    required this.id,
    required this.type,
    required this.by,
    required this.byName,
    required this.approvers,
    required this.createdAt,
    this.status = 'pending',
    this.approvals = const {},
    this.amounts = const {},
    this.period = 0,
    this.expCount = 0,
    this.expTotal = 0,
    this.declinedBy = '',
  });

  final String id;
  final String type; // 'leave' | 'close'
  final String by;
  final String byName;
  final String status; // 'pending' | 'approved' | 'declined'
  final List<String> approvers;
  final Map<String, String> approvals; // uid -> 'approved' | 'declined'

  /// Leave only: approver uid -> amount from the requester's point of view
  /// (positive: requester gets from approver, negative: requester owes approver).
  final Map<String, int> amounts;
  final int period; // close only
  final int expCount; // close only: snapshot when requested
  final int expTotal; // close only: snapshot when requested
  final DateTime createdAt;
  final String declinedBy;

  static String leaveId(String uid) => 'leave_$uid';
  static String closeId(int period) => 'close_$period';

  bool get isLeave => type == 'leave';
  bool get isClose => type == 'close';
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';

  Map<String, dynamic> toMap() => {
    'type': type,
    'by': by,
    'byName': byName,
    'status': 'pending',
    'approvers': approvers,
    'approvals': <String, String>{},
    'amounts': amounts,
    'period': period,
    'expCount': expCount,
    'expTotal': expTotal,
    'declinedBy': '',
    'createdAt': Timestamp.now(),
  };

  factory RoomRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return RoomRequest(
      id: d.id,
      type: (m['type'] as String?) ?? 'leave',
      by: (m['by'] as String?) ?? '',
      byName: (m['byName'] as String?) ?? 'A member',
      status: (m['status'] as String?) ?? 'pending',
      approvers: List<String>.from((m['approvers'] as List?) ?? const []),
      approvals: Map<String, String>.from((m['approvals'] as Map?) ?? const {}),
      amounts: _intMap(m['amounts']),
      period: (m['period'] as num?)?.toInt() ?? 0,
      expCount: (m['expCount'] as num?)?.toInt() ?? 0,
      expTotal: (m['expTotal'] as num?)?.toInt() ?? 0,
      createdAt: _ts(m['createdAt']),
      declinedBy: (m['declinedBy'] as String?) ?? '',
    );
  }
}