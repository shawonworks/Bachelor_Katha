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
    final today = Fmt.dateOnly(DateTime.now());
    var initial = controller.range.value;
    if (initial != null && initial.end.isAfter(today)) {
      initial = DateTimeRange(start: initial.start, end: today);
    }
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today, // no future dates
      initialDateRange: initial,
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

        // Active members, plus anyone who left but still has a balance or activity.
        final people = room.ids.where((id) {
          if (!room.isLeft(id)) return true;
          return (st.net[id] ?? 0) != 0 || (st.paid[id] ?? 0) != 0 || (st.share[id] ?? 0) != 0;
        }).toList();

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
            for (final id in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(children: [
                    Row(children: [
                      Avatar(room.nameOf(id)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(
                              child: Text(
                                  id == me ? '${room.nameOf(id)} (You)' : room.nameOf(id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            if (room.isLeft(id))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding:
                                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Left',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurfaceVariant)),
                              ),
                          ]),
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
              _closeSection(context, room.nameOf, me),
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

  /// Closing needs every other member's approval (unless you are alone in the room).
  Widget _closeSection(BuildContext context, String Function(String) nameOf, String me) {
    final cs = Theme.of(context).colorScheme;
    final req = controller.closeReq;
    final working = controller.closing.value || controller.busy.value;

    if (req == null) {
      return Column(children: [
        AppButton(
          label: controller.hasOthers ? 'Request to close account' : 'Close account & start new',
          icon: Icons.lock_reset_rounded,
          loading: working,
          onPressed: controller.requestClose,
        ),
        if (controller.hasOthers)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Every other member must approve before the account is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
            ),
          ),
      ]);
    }

    if (req.by == me) {
      if (req.isApproved) {
        return AppButton(
          label: 'Everyone approved · Close now',
          icon: Icons.check_rounded,
          color: AppTheme.green,
          loading: working,
          onPressed: controller.requestClose,
        );
      }
      if (req.isDeclined) {
        return Column(children: [
          Text('${nameOf(req.declinedBy)} declined your request to close the account.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.red)),
          const SizedBox(height: 10),
          AppButton(
            label: 'Dismiss and try again later',
            tonal: true,
            onPressed: () => controller.cancelRequest(req),
          ),
        ]);
      }
      final waiting = req.approvers.where((a) => req.approvals[a] != 'approved').length;
      return Column(children: [
        AppButton(
          label: 'Waiting for $waiting approval${waiting == 1 ? '' : 's'}…',
          tonal: true,
          onPressed: null,
        ),
        TextButton(
          onPressed: () => controller.cancelRequest(req),
          child: const Text('Cancel request'),
        ),
      ]);
    }

    return AppButton(
      label: '${req.byName} requested to close · respond on Home',
      tonal: true,
      onPressed: null,
    );
  }
}