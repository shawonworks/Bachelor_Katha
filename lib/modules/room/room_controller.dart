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
import '../../widgets/app_widgets.dart';

/// Holds the live room, current-account expenses, closed accounts (history)
/// and approval requests (leave room / close account), all real-time.
class RoomController extends GetxController {
  RoomController(this.code);
  final String code;

  final session = Get.find<SessionController>();
  final _svc = Get.find<FirestoreService>();

  final room = Rxn<Room>();
  final expenses = <Expense>[].obs;
  final requests = <RoomRequest>[].obs;
  final history = <PeriodRecord>[].obs;
  final historyLoaded = false.obs;
  final loading = true.obs;
  final error = RxnString();
  final range = Rxn<DateTimeRange>(); // summary date filter
  final closing = false.obs;
  final busy = false.obs; // a request action is in flight

  StreamSubscription<Room?>? _roomSub;
  StreamSubscription<List<Expense>>? _expSub;
  StreamSubscription<List<RoomRequest>>? _reqSub;
  StreamSubscription<List<PeriodRecord>>? _histSub;
  int? _period;
  bool _isFirstLoad = true;
  bool _reqFirst = true;
  bool _leaving = false;
  final _lastStatus = <String, String>{};
  final _periodCache = <int, List<Expense>>{};

  String get uid => session.uid;

  @override
  void onInit() {
    super.onInit();
    NotificationService.to.subscribeToRoom(code);
    _roomSub = _svc.roomStream(code).listen(_onRoom, onError: (Object e) {
      if (_leaving) return;
      error.value = Toast.message(e);
      loading.value = false;
    });
    _reqSub = _svc.requestsStream(code).listen(_onRequests, onError: _onStreamError);
    _histSub = _svc.historyStream(code).listen((l) {
      history.assignAll(l);
      historyLoaded.value = true;
      // Warm the cache for the latest closed account so History opens instantly.
      if (l.isNotEmpty) loadPeriod(l.first.no).catchError((_) => <Expense>[]);
    }, onError: _onStreamError);
  }

  void _onStreamError(Object e) {
    if (_leaving) return;
    Toast.error(e);
  }

  void _onRoom(Room? r) {
    if (_leaving) return;
    loading.value = false;
    if (r == null) {
      room.value = null;
      error.value = 'This room no longer exists.';
      return;
    }
    // Left on another device or removed: go back home.
    if (r.isLeft(uid)) {
      leave();
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
        onError: _onStreamError,
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
          final what = e.title.isEmpty ? categoryOf(e.category).label : e.title;
          NotificationService.to.showNotification(
            title: 'New Expense Added ৳',
            body: '$payerName added: $what - ৳${(e.amount / 100).toStringAsFixed(0)}',
          );
        }
      }
    }
    _isFirstLoad = false;
    expenses.assignAll(newList);
  }

  void _onRequests(List<RoomRequest> list) {
    if (_leaving) return;
    if (!_reqFirst) {
      for (final r in list) {
        final prev = _lastStatus[r.id];
        if (prev == null && r.isPending && r.by != uid && r.approvers.contains(uid)) {
          NotificationService.to.showNotification(
            title: 'Approval needed',
            body: '${r.byName} ${r.isLeave ? 'wants to leave the room' : 'wants to close the account'}',
          );
        } else if (prev != null && prev != r.status && r.by == uid) {
          if (r.isApproved) {
            NotificationService.to.showNotification(
              title: 'Request approved',
              body: r.isLeave
                  ? 'Everyone agreed. You can leave the room now.'
                  : 'Everyone agreed. You can close the account now.',
            );
          } else if (r.isDeclined) {
            NotificationService.to.showNotification(
              title: 'Request declined',
              body: '${room.value?.nameOf(r.declinedBy) ?? 'A member'} did not approve your request.',
            );
          }
        }
      }
    }
    _lastStatus
      ..clear()
      ..addEntries(list.map((r) => MapEntry(r.id, r.status)));
    _reqFirst = false;
    requests.assignAll(list);
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

  /// True when at least one other active member is in the room.
  bool get hasOthers => room.value!.activeIds.any((i) => i != uid);

  RoomRequest? _find(bool Function(RoomRequest) test) {
    for (final r in requests) {
      if (test(r)) return r;
    }
    return null;
  }

  RoomRequest? get myLeave => _find((r) => r.id == RoomRequest.leaveId(uid));

  RoomRequest? get closeReq {
    final p = room.value?.period;
    return _find((r) => r.isClose && r.period == p);
  }

  /// Requests waiting for my answer.
  List<RoomRequest> get toRespond {
    final p = room.value?.period;
    return requests
        .where((r) =>
    r.isPending &&
        r.by != uid &&
        r.approvers.contains(uid) &&
        !r.approvals.containsKey(uid) &&
        (!r.isClose || r.period == p))
        .toList();
  }

  /// Requests I created.
  List<RoomRequest> get mine {
    final p = room.value?.period;
    return requests.where((r) => r.by == uid && (!r.isClose || r.period == p)).toList();
  }

  /// Message shown to the person who must approve.
  String approverMessage(RoomRequest r) {
    if (r.isLeave) {
      final amt = r.amounts[uid] ?? 0;
      final money = Money.fmt(amt);
      final detail = amt > 0
          ? '${r.byName} gets $money from you.'
          : amt < 0
          ? '${r.byName} owes you $money.'
          : '';
      return '${r.byName} wants to leave the room. $detail Do you allow ${r.byName} to leave?'
          .replaceAll('  ', ' ');
    }
    final mine = room.value == null ? 0 : (fullStats.net[uid] ?? 0);
    final balance = mine > 0
        ? 'You get ${Money.fmt(mine)}.'
        : mine < 0
        ? 'You owe ${Money.fmt(mine)}.'
        : 'You are settled.';
    return '${r.byName} wants to close this account (${r.expCount} expenses · ${Money.fmt(r.expTotal)}). '
        '$balance Balances will be saved to History and carried forward.';
  }

  // ---------- Expenses ----------
  Future<void> deleteExpense(Expense e) async {
    try {
      await _svc.deleteExpense(code, e.id);
    } catch (err) {
      Toast.error(err);
    }
  }

  /// Expenses of a closed account (cached, so repeat opens are instant).
  Future<List<Expense>> loadPeriod(int no) async {
    final cached = _periodCache[no];
    if (cached != null) return cached;
    final list = await _svc.periodExpenses(code, no);
    _periodCache[no] = list;
    return list;
  }

  // ---------- Leave room ----------
  /// Leaving is free when your balance is settled; otherwise the members you
  /// have money with must approve first.
  Future<void> requestLeave() async {
    final r = room.value;
    if (r == null || busy.value) return;

    final existing = myLeave;
    if (existing != null) {
      if (existing.isApproved) return finishLeave();
      Toast.err(existing.isDeclined
          ? 'Your request was declined. Dismiss it on Home to try again.'
          : 'Your request is already waiting for approval.');
      return;
    }

    final stats = fullStats;
    final myNet = stats.net[uid] ?? 0;

    // Counterparties: members I have a settlement with (same numbers as "Who pays whom").
    final amounts = <String, int>{};
    for (final t in suggestTransfers(stats.net)) {
      if (t.from != uid && t.to != uid) continue;
      final other = t.from == uid ? t.to : t.from;
      if (r.isLeft(other)) continue;
      amounts[other] = (amounts[other] ?? 0) + (t.to == uid ? t.amount : -t.amount);
    }

    if (myNet == 0 || amounts.isEmpty) {
      final yes = await confirm(
        'Leave this room?',
        myNet == 0
            ? 'Your balance is settled. You can rejoin later with the room code.'
            : 'You can rejoin later with the room code. Your balance of ${Money.fmt(myNet)} stays on record.',
        confirmText: 'Leave',
        destructive: true,
      );
      if (yes) await _doLeave();
      return;
    }

    final names = amounts.keys.map(r.nameOf).join(', ');
    final summary = myNet > 0
        ? 'You are owed ${Money.fmt(myNet)}'
        : 'You owe ${Money.fmt(myNet)}';
    final yes = await confirm(
      'Request to leave?',
      '$summary, so you cannot leave right away. A request will be sent to $names. '
          'You can leave once everyone approves.',
      confirmText: 'Send request',
    );
    if (!yes) return;

    busy.value = true;
    try {
      await _svc.createRequest(
        code,
        RoomRequest(
          id: RoomRequest.leaveId(uid),
          type: 'leave',
          by: uid,
          byName: r.nameOf(uid),
          approvers: amounts.keys.toList(),
          amounts: amounts,
          createdAt: DateTime.now(),
        ),
      );
      Toast.ok('Request sent to $names.');
    } catch (e) {
      Toast.error(e);
    }
    busy.value = false;
  }

  Future<void> finishLeave() async {
    final yes = await confirm(
      'Everyone approved',
      'Leave the room now? You can rejoin later with the room code.',
      confirmText: 'Leave',
      destructive: true,
    );
    if (yes) await _doLeave();
  }

  Future<void> _doLeave() async {
    _leaving = true;
    busy.value = true;
    try {
      await _svc.leaveRoom(code, uid);
    } catch (e) {
      _leaving = false;
      busy.value = false;
      Toast.error(e);
      return;
    }
    busy.value = false;
    NotificationService.to.unsubscribeFromRoom(code);
    session.clearRoom();
    Get.offAllNamed(Routes.home);
  }

  // ---------- Close account ----------
  /// Alone in the room: closes directly. Otherwise every other member must approve.
  Future<void> requestClose() async {
    final r = room.value;
    if (r == null || busy.value || closing.value) return;
    if (expenses.isEmpty) {
      Toast.err('No expenses to close yet.');
      return;
    }

    final req = closeReq;
    if (req != null) {
      if (req.by == uid && req.isApproved) return finishClose(req);
      Toast.err(req.by == uid
          ? 'Waiting for everyone to approve.'
          : '${req.byName} has already requested to close this account.');
      return;
    }

    final others = r.activeIds.where((i) => i != uid).toList();
    if (others.isEmpty) {
      final yes = await confirm(
        'Close this account?',
        'The final balances are saved to History and carried forward into a new account. This cannot be undone.',
        confirmText: 'Close account',
      );
      if (yes) await closeAccount();
      return;
    }

    final yes = await confirm(
      'Request to close account?',
      'All ${others.length} other member${others.length == 1 ? '' : 's'} must approve first. '
          'Then balances are saved to History and carried forward into a new account.',
      confirmText: 'Send request',
    );
    if (!yes) return;

    busy.value = true;
    try {
      await _svc.createRequest(
        code,
        RoomRequest(
          id: RoomRequest.closeId(r.period),
          type: 'close',
          by: uid,
          byName: r.nameOf(uid),
          approvers: others,
          period: r.period,
          expCount: expenses.length,
          expTotal: fullStats.total,
          createdAt: DateTime.now(),
        ),
      );
      Toast.ok('Request sent to ${others.length} member${others.length == 1 ? '' : 's'}.');
    } catch (e) {
      Toast.error(e);
    }
    busy.value = false;
  }

  Future<void> finishClose(RoomRequest req) async {
    // Members approved a specific state of the account. If it changed, ask again.
    if (expenses.length != req.expCount || fullStats.total != req.expTotal) {
      await _svc.deleteRequest(code, req.id);
      Toast.err('Expenses changed after the request. Please send a new request.');
      return;
    }
    await closeAccount(requestId: req.id);
  }

  Future<void> closeAccount({String? requestId}) async {
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
      await _svc.closePeriod(
        r,
        net: s.net,
        total: s.total,
        count: expenses.length,
        requestId: requestId,
      );
      ok = true;
    } catch (e) {
      Toast.error(e);
    }
    closing.value = false;
    if (ok) {
      Toast.ok('Account closed. A new account has started.');
      if (Get.currentRoute == Routes.summary) Get.back();
    }
  }

  // ---------- Request answers ----------
  Future<void> respond(RoomRequest r, bool approve) async {
    if (busy.value) return;
    busy.value = true;
    try {
      await _svc.respondRequest(code, r.id, uid, approve);
      Toast.ok(approve ? 'You approved.' : 'You declined.');
    } catch (e) {
      Toast.error(e);
    }
    busy.value = false;
  }

  /// Cancel a pending request, or dismiss a declined one.
  Future<void> cancelRequest(RoomRequest r) async {
    try {
      await _svc.deleteRequest(code, r.id);
    } catch (e) {
      Toast.error(e);
    }
  }

  /// Local switch (used when the room no longer exists or was left elsewhere).
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
    _reqSub?.cancel();
    _histSub?.cancel();
    super.onClose();
  }
}