import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/calc.dart';
import '../../core/utils.dart';
import '../../data/firestore_service.dart';
import '../../data/models.dart';
import '../../widgets/app_widgets.dart';
import '../room/room_controller.dart';

class HistoryView extends GetView<RoomController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<List<PeriodRecord>>(
        stream: Get.find<FirestoreService>().historyStream(controller.code),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
                icon: Icons.error_outline_rounded, title: Toast.message(snap.error!));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'No closed accounts yet',
              subtitle: 'Closed accounts will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = list[i];
              return AppCard(
                onTap: () => _openSheet(p),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Text('#${p.no}',
                        style: TextStyle(
                            color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
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
                  Text(Money.fmt(p.total),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  void _openSheet(PeriodRecord p) {
    Get.bottomSheet(
      _PeriodSheet(record: p, controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _PeriodSheet extends StatelessWidget {
  const _PeriodSheet({required this.record, required this.controller});
  final PeriodRecord record;
  final RoomController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final room = controller.room.value;
    if (room == null) return const SizedBox.shrink();
    final me = controller.uid;
    String who(String id) => id == me ? 'You' : room.nameOf(id);
    final transfers = suggestTransfers(record.balances);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
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
            const SizedBox(height: 16),
            Text('Account #${record.no}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
                '${Fmt.date(record.start)} – ${Fmt.date(record.end)} · Total ${Money.fmt(record.total)}',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SectionTitle('Final balances'),
            AppCard(
              child: Column(children: [
                for (final e in record.balances.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(who(e.key),
                              style: const TextStyle(fontWeight: FontWeight.w700))),
                      NetText(e.value),
                    ]),
                  ),
              ]),
            ),
            if (transfers.isNotEmpty) ...[
              const SectionTitle('To settle'),
              for (final t in transfers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(children: [
                      Expanded(
                        child: Text('${who(t.from)} → ${who(t.to)}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(Money.fmt(t.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ],
            const SectionTitle('Expenses'),
            FutureBuilder<List<Expense>>(
              future: Get.find<FirestoreService>()
                  .periodExpenses(controller.code, record.no),
              builder: (_, s) {
                if (s.hasError) return Text(Toast.message(s.error!));
                if (!s.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Column(children: [
                  for (final e in s.data!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ExpenseTile(expense: e, room: room),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
