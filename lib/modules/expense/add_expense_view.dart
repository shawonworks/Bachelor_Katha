import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../core/utils.dart';
import '../../widgets/app_widgets.dart';
import 'add_expense_controller.dart';

class AddExpenseView extends GetView<AddExpenseController> {
  const AddExpenseView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final room = controller.rc.room.value!;
    final me = controller.rc.uid;
    String who(String id) => id == me ? 'You' : room.nameOf(id);
    String chip(String id) => id == me ? '${room.nameOf(id)} (You)' : room.nameOf(id);

    return Scaffold(
      appBar: AppBar(title: Text(controller.isEdit ? 'Edit expense' : 'Add expense')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: controller.formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppTextField(
                controller: controller.amountC,
                label: 'Amount',
                prefixText: '৳ ',
                autofocus: !controller.isEdit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                onChanged: controller.onAmount,
                validator: (v) => Money.parse(v ?? '') == null ? 'Enter a valid amount' : null,
              ),
              const SizedBox(height: 12),
              // Multi-line note: long text wraps to the next line and the box grows (up to 4 lines).
              AppTextField(
                controller: controller.titleC,
                label: 'Note (optional)',
                hint: 'e.g. Dinner, rice & oil',
                icon: Icons.edit_note_rounded,
                maxLength: 120,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.text,
                action: TextInputAction.done,
                capitalization: TextCapitalization.sentences,
              ),
              const SectionTitle('Category'),
              Obx(() {
                final current = controller.category.value;
                // Old categories (from earlier expenses) stay selectable while editing.
                final list = [
                  ...categories,
                  if (!categories.any((c) => c.id == current) && current.isNotEmpty)
                    categoryOf(current),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in list)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18, color: c.color),
                        label: Text(c.label),
                        selected: current == c.id,
                        onSelected: (_) => controller.setCategory(c.id),
                      ),
                  ],
                );
              }),
              Obx(() => SectionTitle(controller.isLend ? 'Lent by' : 'Paid by')),
              Obx(() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in controller.candidateIds)
                    ChoiceChip(
                      label: Text(chip(id)),
                      selected: controller.paidBy.value == id,
                      onSelected: (_) => controller.setPaidBy(id),
                    ),
                ],
              )),
              Obx(() {
                if (controller.isLend) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Lent to'),
                      _lendSection(context, who, chip),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Split'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                              value: 'equal',
                              icon: Icon(Icons.balance_rounded),
                              label: Text('Equal')),
                          ButtonSegment(
                              value: 'custom',
                              icon: Icon(Icons.tune_rounded),
                              label: Text('Custom')),
                        ],
                        selected: {controller.splitMode.value},
                        onSelectionChanged: (s) => controller.setMode(s.first),
                      ),
                    ),
                    const SizedBox(height: 14),
                    controller.isCustom
                        ? _customSection(context, who)
                        : _equalSection(context, chip),
                  ],
                );
              }),
              const SectionTitle('Date'),
              Obx(() => AppCard(
                onTap: () => controller.pickDate(context),
                child: Row(children: [
                  Icon(Icons.calendar_month_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(Fmt.date(controller.date.value),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ]),
              )),
              const SizedBox(height: 28),
              Obx(() => AppButton(
                label: controller.isEdit ? 'Save changes' : 'Add expense',
                icon: Icons.check_rounded,
                loading: controller.saving.value,
                onPressed: controller.canSave ? controller.save : null,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Lend ----------------
  Widget _lendSection(
      BuildContext context,
      String Function(String) who,
      String Function(String) chip,
      ) {
    final cs = Theme.of(context).colorScheme;
    final payer = controller.paidBy.value;
    final to = controller.lendTo.value;
    final amt = controller.amountPaisa.value;
    final options = controller.candidateIds.where((id) => id != payer).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (options.isEmpty)
          Text('There is nobody else in the room to lend to.',
              style: TextStyle(color: cs.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in options)
                ChoiceChip(
                  label: Text(chip(id)),
                  selected: to == id,
                  onSelected: (_) => controller.lendTo.value = id,
                ),
            ],
          ),
        if (to.isNotEmpty && amt > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${who(payer)} lent ${Money.fmt(amt)} to ${who(to)}. The full amount counts as ${who(to)}\'s due.',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ---------------- Equal split ----------------
  Widget _equalSection(BuildContext context, String Function(String) chip) {
    final cs = Theme.of(context).colorScheme;
    final n = controller.split.length;
    final amt = controller.amountPaisa.value;
    final each = n == 0 ? 0 : (amt / n).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text('Split between',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: controller.selectAll, child: const Text('Select all')),
        ]),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in controller.candidateIds)
              FilterChip(
                label: Text(chip(id)),
                selected: controller.split.contains(id),
                onSelected: (_) => controller.toggleSplit(id),
              ),
          ],
        ),
        if (n > 0 && amt > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${amt % n == 0 ? '' : '≈ '}${Money.fmt(each)} each · $n ${n == 1 ? 'person' : 'people'}',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ---------------- Custom split ----------------
  Widget _customSection(BuildContext context, String Function(String) who) {
    final cs = Theme.of(context).colorScheme;
    final ids = controller.candidateIds;
    final amt = controller.amountPaisa.value;
    final assigned = controller.assigned;
    final rem = controller.remaining;
    final ok = amt > 0 && rem == 0 && assigned > 0;

    final String status;
    if (amt == 0) {
      status = 'Enter the total amount first';
    } else if (ok) {
      status = 'Assigned ${Money.fmt(assigned)} / ${Money.fmt(amt)} ✓';
    } else if (rem > 0) {
      status = '${Money.fmt(rem)} left to assign';
    } else {
      status = '${Money.fmt(rem)} extra, reduce some shares';
    }
    final statusColor = ok ? AppTheme.green : (amt == 0 ? cs.onSurfaceVariant : AppTheme.red);

    final owes = ok ? controller.owesPayer : const <MapEntry<String, int>>[];
    final payer = controller.paidBy.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Column(children: [
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Avatar(who(id) == 'You' ? 'Y' : who(id), size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(who(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 130,
                    child: AppTextField(
                      controller: controller.customC[id]!,
                      label: 'Share',
                      prefixText: '৳ ',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (v) => controller.onShare(id, v),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w800)),
          ),
          TextButton.icon(
            onPressed: controller.splitRemainingEqually,
            icon: const Icon(Icons.call_split_rounded, size: 18),
            label: const Text('Split remaining'),
          ),
        ]),
        if (owes.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final e in owes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${who(e.key)} ${e.key == controller.rc.uid ? 'owe' : 'owes'} ${who(payer)} ${Money.fmt(e.value)}',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ],
    );
  }
}