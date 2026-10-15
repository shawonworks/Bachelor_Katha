import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../core/calc.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/expense_detail_sheet.dart';
import '../room/room_controller.dart';

/// Closed accounts, newest first, grouped by month. Data is preloaded by
/// [RoomController], so this screen opens instantly.
class HistoryView extends GetView<RoomController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Obx(() {
        if (!controller.historyLoaded.value) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: SkeletonList(count: 4),
          );
        }
        final list = controller.history;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'No closed accounts yet',
            subtitle: 'When an account is closed, its full record is saved here.',
          );
        }
        final me = controller.uid;

        // Month headers + cards.
        final items = <Object>[];
        String? currentMonth;
        for (final p in list) {
          final m = Fmt.month(p.end);
          if (m != currentMonth) {
            items.add(m);
            currentMonth = m;
          }
          items.add(p);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                child: Text(item,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
              );
            }
            final p = item as PeriodRecord;
            final myNet = p.balances[me] ?? 0;
            final resultColor =
            myNet > 0 ? AppTheme.green : myNet < 0 ? AppTheme.red : cs.onSurfaceVariant;
            final resultText = myNet > 0
                ? 'You were owed ${Money.fmt(myNet)}'
                : myNet < 0
                ? 'You owed ${Money.fmt(myNet)}'
                : 'You were settled';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => Get.to(() => PeriodDetailView(record: p)),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text('#${p.no}',
                        style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${Fmt.short(p.start)} – ${Fmt.date(p.end)}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${p.count} expenses',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Money.fmt(p.total),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(resultText,
                        style: TextStyle(
                            color: resultColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ]),
                ]),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Full record of one closed account: Overview, Expenses and Settlement tabs.
class PeriodDetailView extends StatefulWidget {
  const PeriodDetailView({super.key, required this.record});
  final PeriodRecord record;

  @override
  State<PeriodDetailView> createState() => _PeriodDetailViewState();
}

class _PeriodDetailViewState extends State<PeriodDetailView> {
  final c = Get.find<RoomController>();
  late final Future<List<Expense>> _expenses = c.loadPeriod(widget.record.no);

  @override
  Widget build(BuildContext context) {
    final p = widget.record;
    final room = c.room.value;
    if (room == null) return const Scaffold(body: SizedBox.shrink());
    final me = c.uid;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Account #${p.no}'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Overview'), Tab(text: 'Expenses'), Tab(text: 'Settlement')],
          ),
        ),
        body: TabBarView(
          children: [
            _Overview(record: p, room: room, me: me, expenses: _expenses),
            _ExpensesTab(room: room, me: me, expenses: _expenses),
            _SettlementTab(record: p, room: room, me: me),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.record,
    required this.room,
    required this.me,
    required this.expenses,
  });
  final PeriodRecord record;
  final Room room;
  final String me;
  final Future<List<Expense>> expenses;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = record;
    final myNet = p.balances[me] ?? 0;
    final resultColor =
    myNet > 0 ? AppTheme.green : myNet < 0 ? AppTheme.red : cs.onSurfaceVariant;
    final resultText = myNet > 0
        ? 'You were owed ${Money.fmt(myNet)}'
        : myNet < 0
        ? 'You owed ${Money.fmt(myNet)}'
        : 'You were settled';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Fmt.date(p.start)} – ${Fmt.date(p.end)}',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(Money.fmt(p.total),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            Text('${p.count} expenses in total',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(resultText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: resultColor, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        const SectionTitle('By category'),
        FutureBuilder<List<Expense>>(
          future: expenses,
          builder: (_, s) {
            if (s.hasError) return Text(Toast.message(s.error!));
            if (!s.hasData) {
              return const Column(children: [
                AppSkeleton(height: 18),
                SizedBox(height: 14),
                AppSkeleton(height: 18),
                SizedBox(height: 14),
                AppSkeleton(height: 18),
              ]);
            }
            return _CategoryBars(expenses: s.data!, total: p.total);
          },
        ),
        const SectionTitle('Final balances'),
        AppCard(
          child: Column(children: [
            for (final e in p.balances.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Avatar(room.nameOf(e.key), size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(e.key == me ? '${room.nameOf(e.key)} (You)' : room.nameOf(e.key),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  NetText(e.value),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.expenses, required this.total});
  final List<Expense> expenses;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sums = <String, int>{};
    for (final e in expenses) {
      final id = categoryOf(e.category).id;
      sums[id] = (sums[id] ?? 0) + e.amount;
    }
    final rows = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sum = rows.fold<int>(0, (a, b) => a + b.value);
    if (rows.isEmpty) {
      return Text('No expense data available.', style: TextStyle(color: cs.onSurfaceVariant));
    }
    return AppCard(
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(children: [
              Row(children: [
                Icon(categoryOf(r.key).icon, size: 18, color: categoryOf(r.key).color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(categoryOf(r.key).label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${Money.fmt(r.value)} · ${sum == 0 ? 0 : (r.value * 100 / sum).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: sum == 0 ? 0 : r.value / sum,
                  minHeight: 6,
                  color: categoryOf(r.key).color,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({required this.room, required this.me, required this.expenses});
  final Room room;
  final String me;
  final Future<List<Expense>> expenses;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Expense>>(
      future: expenses,
      builder: (_, s) {
        if (s.hasError) return EmptyState(icon: Icons.error_outline_rounded, title: Toast.message(s.error!));
        if (!s.hasData) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SkeletonList(count: 5),
          );
        }
        final list = s.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'No expense records found',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final e = list[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ExpenseTile(
                expense: e,
                room: room,
                me: me,
                onTap: () => showExpenseDetails(e, room, me),
              ),
            );
          },
        );
      },
    );
  }
}

class _SettlementTab extends StatelessWidget {
  const _SettlementTab({required this.record, required this.room, required this.me});
  final PeriodRecord record;
  final Room room;
  final String me;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final transfers = suggestTransfers(record.balances);
    String who(String id) => id == me ? 'You' : room.nameOf(id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (transfers.isEmpty)
          const AppCard(
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.green),
              SizedBox(width: 12),
              Expanded(
                child: Text('Everyone was settled up when this account closed.',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          )
        else ...[
          const SectionTitle('Who pays whom'),
          for (final t in transfers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${who(t.from)} ${t.from == me ? 'pay' : 'pays'} ${who(t.to)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(Money.fmt(t.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'These balances were carried forward into the next account.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
        ],
      ],
    );
  }
}