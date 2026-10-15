import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/calc.dart';
import '../../core/notification_service.dart';
import '../../core/session_controller.dart';
import '../../core/utils.dart';
import '../../data/firestore_service.dart';
import '../../data/models.dart';

/// Holds the live room + current-account expenses (real-time Firestore streams).
class RoomController extends GetxController {
  RoomController(this.code);
  final String code;

  final session = Get.find<SessionController>();
  final _svc = Get.find<FirestoreService>();

  final room = Rxn<Room>();
  final expenses = <Expense>[].obs;
  final loading = true.obs;
  final error = RxnString();
  final range = Rxn<DateTimeRange>(); // summary date filter
  final closing = false.obs;

  StreamSubscription<Room?>? _roomSub;
  StreamSubscription<List<Expense>>? _expSub;
  int? _period;
  bool _isFirstLoad = true;

  String get uid => session.uid;

  @override
  void onInit() {
    super.onInit();
    NotificationService.to.subscribeToRoom(code);
    _roomSub = _svc.roomStream(code).listen(_onRoom, onError: (Object e) {
      error.value = Toast.message(e);
      loading.value = false;
    });
  }

  void _onRoom(Room? r) {
    loading.value = false;
    if (r == null) {
      room.value = null;
      error.value = 'This room no longer exists.';
      return;
    }
    room.value = r;
    if (_period != r.period) {
      _period = r.period;
      range.value = null;
      expenses.clear();
      _isFirstLoad = true;
      _expSub?.cancel();
      _expSub = _svc.expenseStream(code, r.period).listen(
            _onExpensesReceived,
            onError: (Object e) => Toast.error(e),
          );
    }
  }

  void _onExpensesReceived(List<Expense> newList) {
    if (!_isFirstLoad) {
      // Check for newly added items from other users
      final existingIds = expenses.map((e) => e.id).toSet();
      for (final e in newList) {
        if (!existingIds.contains(e.id) && e.createdBy != uid) {
          final payerName = room.value?.members[e.paidBy] ?? 'A member';
          NotificationService.to.showNotification(
            title: 'New Expense Added ৳',
            body: '$payerName added: ${e.title} - ৳${(e.amount / 100).toStringAsFixed(0)}',
          );
        }
      }
    }
    _isFirstLoad = false;
    expenses.assignAll(newList);
  }

  // ---------- Derived data ----------
  /// Whole current account, including carried-forward opening balances.
  Stats get fullStats {
    final r = room.value!;
    return computeStats(r.ids, expenses, opening: r.opening);
  }

  List<Expense> get filtered {
    final r = range.value;
    if (r == null) return expenses.toList();
    return expenses
        .where((e) => !e.date.isBefore(r.start) && !e.date.isAfter(r.end))
        .toList();
  }

  /// Stats for the Summary screen (respects the date filter).
  Stats get stats {
    final r = room.value!;
    final filtering = range.value != null;
    return computeStats(r.ids, filtered, opening: filtering ? const {} : r.opening);
  }

  // ---------- Actions ----------
  Future<void> deleteExpense(Expense e) async {
    try {
      await _svc.deleteExpense(code, e.id);
    } catch (err) {
      Toast.error(err);
    }
  }

  Future<void> closeAccount() async {
    final r = room.value;
    if (r == null) return;
    if (expenses.isEmpty) {
      Toast.err('No expenses to close yet.');
      return;
    }
    closing.value = true;
    var ok = false;
    try {
      final s = fullStats;
      await _svc.closePeriod(r, net: s.net, total: s.total, count: expenses.length);
      ok = true;
    } catch (e) {
      Toast.error(e);
    }
    closing.value = false;
    if (ok) {
      Toast.ok('Account closed. A new account has started.');
      Get.back();
    }
  }

  void leave() {
    NotificationService.to.unsubscribeFromRoom(code);
    session.clearRoom();
    Get.offAllNamed(Routes.home);
  }

  @override
  void onClose() {
    NotificationService.to.unsubscribeFromRoom(code);
    _roomSub?.cancel();
    _expSub?.cancel();
    super.onClose();
  }
}
