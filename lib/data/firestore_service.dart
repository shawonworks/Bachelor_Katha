import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'models.dart';

class FirestoreService extends GetxService {
  static const maxMembers = 10;

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('rooms');
  CollectionReference<Map<String, dynamic>> _requests(String code) =>
      _rooms.doc(code).collection('requests');

  /// Offline-friendly write: Firestore queues it locally and syncs later,
  /// so we don't block the UI waiting for the server ack.
  Future<void> _write(Future<void> f) =>
      f.timeout(const Duration(seconds: 4), onTimeout: () {});

  // ---------- Rooms ----------
  Future<String> createRoom({
    required String name,
    required String uid,
    required String userName,
  }) async {
    final rnd = Random.secure();
    for (var i = 0; i < 8; i++) {
      final code = (100000 + rnd.nextInt(900000)).toString();
      final ref = _rooms.doc(code);
      final created = await _db.runTransaction<bool>((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          'name': name,
          'ownerId': uid,
          'memberIds': [uid],
          'members': {uid: userName},
          'left': <String>[],
          'period': 1,
          'periodStart': Timestamp.now(),
          'opening': {uid: 0},
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (created) return code;
    }
    throw 'Could not create the room. Please try again.';
  }

  /// Joins a room. Someone who left earlier can rejoin with the same code
  /// (their old balance is kept).
  Future<void> joinRoom({
    required String code,
    required String uid,
    required String userName,
  }) async {
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'No room found with this code.';
      final m = snap.data()!;
      final ids = List<String>.from(m['memberIds'] ?? const []);
      if (ids.contains(uid)) return;
      if (ids.length >= maxMembers) throw 'This room is full ($maxMembers members max).';
      final left = List<String>.from(m['left'] ?? const []);
      if (left.contains(uid)) {
        tx.update(ref, {
          'memberIds': FieldValue.arrayUnion([uid]),
          'left': FieldValue.arrayRemove([uid]),
          'members.$uid': userName,
        });
      } else {
        tx.update(ref, {
          'memberIds': FieldValue.arrayUnion([uid]),
          'members.$uid': userName,
          'opening.$uid': 0,
        });
      }
    });
  }

  /// Marks the member as left. Their name and balance stay on record.
  Future<void> leaveRoom(String code, String uid) async {
    final ref = _rooms.doc(code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      tx.update(ref, {
        'memberIds': FieldValue.arrayRemove([uid]),
        'left': FieldValue.arrayUnion([uid]),
      });
      tx.delete(_requests(code).doc(RoomRequest.leaveId(uid)));
    });
  }

  Stream<Room?> roomStream(String code) =>
      _rooms.doc(code).snapshots().map((s) => s.exists ? Room.fromDoc(s) : null);

  // ---------- Expenses ----------
  /// Filtered by a single field only => no composite index needed. Sorted on device.
  Stream<List<Expense>> expenseStream(String code, int period) => _rooms
      .doc(code)
      .collection('expenses')
      .where('period', isEqualTo: period)
      .snapshots()
      .map((s) {
    final list = s.docs.map(Expense.fromDoc).toList();
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  });

  Future<void> addExpense(String code, Expense e) =>
      _write(_rooms.doc(code).collection('expenses').doc().set(e.toMap()));

  Future<void> updateExpense(String code, Expense e) =>
      _write(_rooms.doc(code).collection('expenses').doc(e.id).set(e.toMap()));

  Future<void> deleteExpense(String code, String id) =>
      _write(_rooms.doc(code).collection('expenses').doc(id).delete());

  /// Expenses of a closed account. Closed accounts never change, so the local
  /// cache is tried first (instant) and the server only when the cache is empty.
  Future<List<Expense>> periodExpenses(String code, int period) async {
    final q = _rooms
        .doc(code)
        .collection('expenses')
        .where('period', isEqualTo: period);
    QuerySnapshot<Map<String, dynamic>> s;
    try {
      s = await q.get(const GetOptions(source: Source.cache));
      if (s.docs.isEmpty) s = await q.get();
    } catch (_) {
      s = await q.get();
    }
    final list = s.docs.map(Expense.fromDoc).toList();
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  // ---------- Close account / history ----------
  /// Saves a snapshot of the current period and starts the next one with the
  /// final balances as opening balances (carry forward).
  /// If [requestId] is given, that approval request is removed in the same transaction.
  Future<void> closePeriod(
      Room room, {
        required Map<String, int> net,
        required int total,
        required int count,
        String? requestId,
      }) async {
    final ref = _rooms.doc(room.code);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['period'] as num?)?.toInt();
      if (current != room.period) throw 'This account was already closed.';
      tx.set(ref.collection('periods').doc('${room.period}'), {
        'no': room.period,
        'start': Timestamp.fromDate(room.periodStart),
        'end': Timestamp.now(),
        'total': total,
        'count': count,
        'balances': net,
      });
      tx.update(ref, {
        'period': room.period + 1,
        'periodStart': Timestamp.now(),
        'opening': net,
      });
      if (requestId != null) tx.delete(_requests(room.code).doc(requestId));
    });
  }

  Stream<List<PeriodRecord>> historyStream(String code) =>
      _rooms.doc(code).collection('periods').snapshots().map((s) {
        final list = s.docs.map(PeriodRecord.fromDoc).toList();
        list.sort((a, b) => b.no.compareTo(a.no));
        return list;
      });

  // ---------- Approval requests (leave room / close account) ----------
  Stream<List<RoomRequest>> requestsStream(String code) =>
      _requests(code).snapshots().map((s) {
        final list = s.docs.map(RoomRequest.fromDoc).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });

  Future<void> createRequest(String code, RoomRequest r) =>
      _write(_requests(code).doc(r.id).set(r.toMap()));

  Future<void> deleteRequest(String code, String id) =>
      _write(_requests(code).doc(id).delete());

  /// Records one member's answer. Any "decline" declines the request;
  /// when every approver has approved, it becomes "approved".
  Future<void> respondRequest(String code, String id, String uid, bool approve) async {
    final ref = _requests(code).doc(id);
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (!s.exists) throw 'This request is no longer available.';
      final m = s.data()!;
      if (m['status'] != 'pending') return;
      final approvers = List<String>.from(m['approvers'] ?? const []);
      if (!approvers.contains(uid)) throw 'You are not part of this request.';
      final approvals = Map<String, String>.from(m['approvals'] ?? const {});
      approvals[uid] = approve ? 'approved' : 'declined';
      var status = 'pending';
      if (!approve) {
        status = 'declined';
      } else if (approvers.every((a) => approvals[a] == 'approved')) {
        status = 'approved';
      }
      tx.update(ref, {
        'approvals.$uid': approvals[uid],
        'status': status,
        if (!approve) 'declinedBy': uid,
      });
    });
  }
}