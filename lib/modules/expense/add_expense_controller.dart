import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils.dart';
import '../../data/firestore_service.dart';
import '../../data/models.dart';
import '../room/room_controller.dart';

class AddExpenseController extends GetxController {
  final Expense? editing = Get.arguments as Expense?;
  final rc = Get.find<RoomController>();
  final _svc = Get.find<FirestoreService>();

  final formKey = GlobalKey<FormState>();
  final amountC = TextEditingController();
  final titleC = TextEditingController();

  final category = ''.obs;
  final paidBy = ''.obs;
  final split = <String>{}.obs;
  final date = Fmt.dateOnly(DateTime.now()).obs;
  final amountPaisa = 0.obs;
  final saving = false.obs;

  // ---- Lend: one person borrowed the full amount ----
  final lendTo = ''.obs;

  // ---- Custom split ----
  final splitMode = 'equal'.obs; // 'equal' | 'custom'
  final customC = <String, TextEditingController>{}; // uid -> field controller
  final customPaisa = <String, int>{}.obs; // uid -> entered share (paisa)

  bool get isEdit => editing != null;
  bool get isCustom => splitMode.value == 'custom';
  bool get isLend => category.value == 'lend';

  int get assigned => customPaisa.values.fold(0, (a, b) => a + b);
  int get remaining => amountPaisa.value - assigned;

  /// Lend needs a borrower. Custom split needs an exact match. Equal keeps old behaviour.
  bool get canSave {
    if (isLend) return lendTo.value.isNotEmpty && lendTo.value != paidBy.value;
    return !isCustom || (amountPaisa.value > 0 && remaining == 0 && assigned > 0);
  }

  /// Active members, plus anyone who already took part in the expense being edited.
  List<String> get candidateIds {
    final room = rc.room.value!;
    final involved = <String>{
      if (editing != null) ...editing!.split,
      if (editing != null) ...editing!.shares.keys,
      if (editing != null) editing!.paidBy,
    };
    return room.ids.where((id) => !room.isLeft(id) || involved.contains(id)).toList();
  }

  static String _input(int paisa) =>
      (paisa / 100).toStringAsFixed(paisa % 100 == 0 ? 0 : 2);

  @override
  void onInit() {
    super.onInit();
    final room = rc.room.value!;
    for (final id in room.ids) {
      customC[id] = TextEditingController();
      customPaisa[id] = 0;
    }

    final e = editing;
    if (e != null) {
      amountC.text = _input(e.amount);
      amountPaisa.value = e.amount;
      titleC.text = e.title;
      category.value = e.category;
      paidBy.value = e.paidBy;
      split.addAll(e.split);
      date.value = Fmt.dateOnly(e.date);
      if (e.isLend && e.split.length == 1) lendTo.value = e.split.first;
      if (e.isCustom) {
        splitMode.value = 'custom';
        e.shares.forEach((id, v) {
          customC.putIfAbsent(id, () => TextEditingController()).text = v == 0 ? '' : _input(v);
          customPaisa[id] = v;
        });
      }
    } else {
      category.value = defaultCategoryNow();
      paidBy.value = rc.uid;
      split.addAll(room.activeIds);
    }
  }

  void onAmount(String v) => amountPaisa.value = Money.parse(v) ?? 0;

  void setCategory(String id) => category.value = id;

  void setPaidBy(String id) {
    paidBy.value = id;
    if (lendTo.value == id) lendTo.value = '';
  }

  void setMode(String mode) => splitMode.value = mode;

  void toggleSplit(String id) => split.contains(id) ? split.remove(id) : split.add(id);

  void selectAll() => split.addAll(candidateIds);

  void onShare(String id, String v) => customPaisa[id] = Money.parse(v) ?? 0;

  /// Divides what is still unassigned equally among members whose field is empty/0.
  void splitRemainingEqually() {
    final rem = remaining;
    final targets = candidateIds.where((id) => (customPaisa[id] ?? 0) == 0).toList();
    if (amountPaisa.value == 0) {
      Toast.err('Enter the total amount first.');
      return;
    }
    if (targets.isEmpty || rem <= 0) {
      Toast.err('Nothing left to split.');
      return;
    }
    final base = rem ~/ targets.length;
    var extra = rem - base * targets.length;
    for (final id in targets) {
      final v = base + (extra > 0 ? 1 : 0);
      if (extra > 0) extra--;
      customPaisa[id] = v;
      customC[id]!.text = _input(v);
    }
  }

  /// Who owes the payer (custom mode preview).
  List<MapEntry<String, int>> get owesPayer => customPaisa.entries
      .where((e) => e.key != paidBy.value && e.value > 0)
      .toList();

  Future<void> pickDate(BuildContext context) async {
    // Expenses are records of money already spent, so no future dates.
    final today = Fmt.dateOnly(DateTime.now());
    final initial = date.value.isAfter(today) ? today : date.value;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (d != null) date.value = Fmt.dateOnly(d);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final lend = isLend;
    final custom = !lend && isCustom;

    if (lend) {
      if (lendTo.value.isEmpty || lendTo.value == paidBy.value) {
        Toast.err('Choose who you lent the money to.');
        return;
      }
    } else if (custom) {
      if (remaining != 0 || assigned <= 0) {
        Toast.err('Shares must add up to the total amount.');
        return;
      }
    } else if (split.isEmpty) {
      Toast.err('Select at least one person to split with.');
      return;
    }
    final room = rc.room.value;
    if (room == null) return;

    final shares = custom
        ? {for (final e in customPaisa.entries) if (e.value > 0) e.key: e.value}
        : <String, int>{};
    final people = lend
        ? [lendTo.value]
        : custom
        ? (shares.keys.toList()..sort())
        : (split.toList()..sort());

    saving.value = true;
    var ok = false;
    try {
      final e = Expense(
        id: editing?.id ?? '',
        title: titleC.text.trim(),
        amount: Money.parse(amountC.text)!,
        category: category.value,
        paidBy: paidBy.value,
        split: people,
        splitType: custom ? 'custom' : 'equal',
        shares: shares,
        date: date.value,
        createdAt: editing?.createdAt ?? DateTime.now(),
        createdBy: editing?.createdBy ?? rc.uid,
        period: editing?.period ?? room.period,
      );
      isEdit ? await _svc.updateExpense(rc.code, e) : await _svc.addExpense(rc.code, e);
      ok = true;
    } catch (err) {
      Toast.error(err);
    }
    saving.value = false;
    if (ok) Get.back();
  }

  @override
  void onClose() {
    amountC.dispose();
    titleC.dispose();
    for (final c in customC.values) {
      c.dispose();
    }
    super.onClose();
  }
}