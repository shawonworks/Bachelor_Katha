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

  final category = 'food'.obs;
  final paidBy = ''.obs;
  final split = <String>{}.obs;
  final date = Fmt.dateOnly(DateTime.now()).obs;
  final amountPaisa = 0.obs;
  final saving = false.obs;

  // ---- Custom split ----
  final splitMode = 'equal'.obs; // 'equal' | 'custom'
  final customC = <String, TextEditingController>{}; // uid -> field controller
  final customPaisa = <String, int>{}.obs; // uid -> entered share (paisa)

  bool get isEdit => editing != null;
  bool get isCustom => splitMode.value == 'custom';

  int get assigned => customPaisa.values.fold(0, (a, b) => a + b);
  int get remaining => amountPaisa.value - assigned;

  /// Equal mode keeps the old behaviour. Custom mode needs an exact match.
  bool get canSave => !isCustom || (amountPaisa.value > 0 && remaining == 0 && assigned > 0);

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
      if (e.isCustom) {
        splitMode.value = 'custom';
        e.shares.forEach((id, v) {
          customC.putIfAbsent(id, () => TextEditingController()).text = v == 0 ? '' : _input(v);
          customPaisa[id] = v;
        });
      }
    } else {
      paidBy.value = rc.uid;
      split.addAll(room.ids);
    }
  }

  void onAmount(String v) => amountPaisa.value = Money.parse(v) ?? 0;

  void setMode(String mode) => splitMode.value = mode;

  void toggleSplit(String id) => split.contains(id) ? split.remove(id) : split.add(id);

  void selectAll() => split.addAll(rc.room.value!.ids);

  void onShare(String id, String v) => customPaisa[id] = Money.parse(v) ?? 0;

  /// Divides what is still unassigned equally among members whose field is empty/0.
  void splitRemainingEqually() {
    final rem = remaining;
    final targets = rc.room.value!.ids.where((id) => (customPaisa[id] ?? 0) == 0).toList();
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
    final d = await showDatePicker(
      context: context,
      initialDate: date.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) date.value = Fmt.dateOnly(d);
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    final custom = isCustom;
    if (custom) {
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
    final people = custom ? (shares.keys.toList()..sort()) : (split.toList()..sort());

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