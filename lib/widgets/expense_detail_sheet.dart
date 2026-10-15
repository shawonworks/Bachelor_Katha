import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/app_theme.dart';
import '../core/utils.dart';
import '../data/models.dart';
import 'app_widgets.dart';

/// Read-only details of an expense: what, how much, who paid, who added it,
/// how it was split and what it means for the viewer.
void showExpenseDetails(Expense e, Room room, String me) {
  Get.bottomSheet(
    _ExpenseDetail(expense: e, room: room, me: me),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _ExpenseDetail extends StatelessWidget {
  const _ExpenseDetail({required this.expense, required this.room, required this.me});
  final Expense expense;
  final Room room;
  final String me;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = expense;
    final cat = categoryOf(e.category);
    String name(String id) => id == me ? 'You' : room.nameOf(id);

    final impact = e.impactOn(me);
    final involved = e.paidBy == me || e.shareMap.containsKey(me);
    final Color impactColor =
    impact > 0 ? AppTheme.green : impact < 0 ? AppTheme.red : cs.onSurfaceVariant;
    final String impactText = impact > 0
        ? 'You get ${Money.fmt(impact)} from this expense'
        : impact < 0
        ? 'You owe ${Money.fmt(impact)} for this expense'
        : involved
        ? 'No balance change for you'
        : "You're not part of this expense";

    final shares = e.shareMap.entries.toList()
      ..sort((a, b) => room.nameOf(a.key).toLowerCase().compareTo(room.nameOf(b.key).toLowerCase()));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.outlineVariant, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: cat.color.withValues(alpha: 0.15),
                child: Icon(cat.icon, color: cat.color, size: 30),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(Money.fmt(e.amount),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('${cat.label} · ${Fmt.date(e.date)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: impactColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(impactText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: impactColor, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (e.isLend && e.split.length == 1) ...[
              const SizedBox(height: 10),
              AppCard(
                child: Row(children: [
                  Icon(Icons.handshake_rounded, color: cat.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${name(e.paidBy)} lent ${Money.fmt(e.amount)} to ${name(e.split.first)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ],
            if (e.title.isNotEmpty) ...[
              const SectionTitle('Note'),
              AppCard(
                child: SizedBox(
                  width: double.infinity,
                  child: SelectableText(e.title, style: const TextStyle(height: 1.4)),
                ),
              ),
            ],
            const SectionTitle('Details'),
            AppCard(
              child: Column(children: [
                _Row('Paid by', name(e.paidBy)),
                _Row('Added by', name(e.createdBy)),
                _Row('Date', Fmt.date(e.date)),
                _Row('Added on', Fmt.dateTime(e.createdAt)),
                _Row('Split', e.isCustom ? 'Custom amounts' : 'Equally among ${e.split.length}'),
              ]),
            ),
            SectionTitle('Who owes what', trailing: Text('${shares.length} people')),
            AppCard(
              child: Column(children: [
                for (final s in shares)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(children: [
                      Avatar(room.nameOf(s.key), size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name(s.key),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      if (s.key == e.paidBy)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Paid',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onPrimaryContainer)),
                        ),
                      Text(Money.fmt(s.value),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                if (!e.shareMap.containsKey(e.paidBy))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${name(e.paidBy)} paid and is not part of the split.',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 92,
          child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}