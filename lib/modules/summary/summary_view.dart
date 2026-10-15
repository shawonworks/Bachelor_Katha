import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../core/calc.dart';
import '../../core/utils.dart';
import '../../widgets/app_widgets.dart';
import '../room/room_controller.dart';

class SummaryView extends GetView<RoomController> {
  const SummaryView({super.key});

  Future<void> _pickRange(BuildContext context) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: controller.range.value,
    );
    if (r != null) controller.range.value = r;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: Obx(() {
        final room = controller.room.value;
        if (room == null) return const SizedBox.shrink();
        final me = controller.uid;
        final st = controller.stats;
        final range = controller.range.value;
        final filtering = range != null;
        final transfers = suggestTransfers(st.net);
        final count = controller.filtered.length;

        String who(String id) => id == me ? 'You' : room.nameOf(id);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                Icon(Icons.date_range_rounded, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filtering
                        ? '${Fmt.date(range.start)} – ${Fmt.date(range.end)}'
                        : 'Whole account · since ${Fmt.date(room.periodStart)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: () => _pickRange(context), child: const Text('Filter')),
                if (filtering)
                  IconButton(
                    tooltip: 'Clear filter',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => controller.range.value = null,
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total spent', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(Money.fmt(st.total),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ]),
                ),
                Text('$count ${count == 1 ? 'expense' : 'expenses'}',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ]),
            ),
            const SectionTitle('Per person'),
            for (final id in room.ids)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(children: [
                    Row(children: [
                      Avatar(room.nameOf(id)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(id == me ? '${room.nameOf(id)} (You)' : room.nameOf(id),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            'Paid ${Money.fmt(st.paid[id] ?? 0)} · Share ${Money.fmt(st.share[id] ?? 0)}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ]),
                      ),
                      NetText(st.net[id] ?? 0, big: true),
                    ]),
                    if (!filtering && (room.opening[id] ?? 0) != 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Includes ${(room.opening[id] ?? 0) > 0 ? 'credit' : 'due'} of ${Money.fmt(room.opening[id] ?? 0)} carried forward',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            if (!filtering) ...[
              const SectionTitle('Who pays whom'),
              if (transfers.isEmpty)
                const AppCard(
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.green),
                    SizedBox(width: 12),
                    Text('Everyone is settled up',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                )
              else
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
              const SizedBox(height: 18),
              AppButton(
                label: 'Close account & start new',
                icon: Icons.lock_reset_rounded,
                loading: controller.closing.value,
                onPressed: () async {
                  final yes = await confirm(
                    'Close this account?',
                    'The final balances are saved to History and carried forward into a new account. This cannot be undone.',
                    confirmText: 'Close account',
                  );
                  if (yes) controller.closeAccount();
                },
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Filtered view shows only expenses in the selected dates. Clear the filter to settle up or close the account.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ),
          ],
        );
      }),
    );
  }
}
