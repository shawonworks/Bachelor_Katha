import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/app_theme.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/expense_detail_sheet.dart';
import 'requests_panel.dart';
import 'room_controller.dart';

class _DayHeader {
  const _DayHeader(this.date, this.total);
  final DateTime date;
  final int total;
}

class DashboardView extends GetView<RoomController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.room.value?.name ?? 'Room')),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: controller.session.toggleTheme,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'leave') controller.requestLeave();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'leave',
                child: Row(children: [
                  Icon(Icons.logout_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Leave room'),
                ]),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(Routes.add),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add expense'),
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              AppSkeleton(height: 150, radius: 26),
              SizedBox(height: 14),
              SkeletonList(count: 3),
            ]),
          );
        }
        final room = controller.room.value;
        if (room == null) {
          return EmptyState(
            icon: Icons.error_outline_rounded,
            title: controller.error.value ?? 'Room not found',
            actionLabel: 'Back to home',
            onAction: controller.leave,
          );
        }
        final stats = controller.fullStats;
        final list = controller.expenses;
        final me = controller.uid;

        // Group by day (list is already sorted newest first).
        final dayTotals = <DateTime, int>{};
        for (final e in list) {
          final d = Fmt.dateOnly(e.date);
          dayTotals[d] = (dayTotals[d] ?? 0) + e.amount;
        }
        final items = <Object>[];
        DateTime? current;
        for (final e in list) {
          final d = Fmt.dateOnly(e.date);
          if (current != d) {
            items.add(_DayHeader(d, dayTotals[d] ?? 0));
            current = d;
          }
          items.add(e);
        }

        final shownMembers =
        room.ids.where((id) => !room.isLeft(id) || (stats.net[id] ?? 0) != 0).toList();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BalanceCard(
                      net: stats.net[me] ?? 0,
                      total: stats.total,
                      since: room.periodStart,
                    ),
                    const RequestsPanel(),
                    const SizedBox(height: 14),
                    _CodeCard(code: room.code),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: AppButton(
                          label: 'Summary',
                          icon: Icons.pie_chart_rounded,
                          tonal: true,
                          onPressed: () => Get.toNamed(Routes.summary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'History',
                          icon: Icons.history_rounded,
                          tonal: true,
                          onPressed: () => Get.toNamed(Routes.history),
                        ),
                      ),
                    ]),
                    SectionTitle('Members (${room.activeIds.length})'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          for (final id in shownMembers)
                            _MemberRow(
                              name: room.nameOf(id),
                              isMe: id == me,
                              left: room.isLeft(id),
                              net: stats.net[id] ?? 0,
                            ),
                        ],
                      ),
                    ),
                    SectionTitle('Expenses', trailing: Text('${list.length}')),
                    if (list.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No expenses yet',
                        subtitle: 'Tap "Add expense" to record the first one.',
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  if (item is _DayHeader) return _DayHeaderRow(item);
                  final e = item as Expense;
                  final mine = e.createdBy == me;
                  final tile = ExpenseTile(
                    expense: e,
                    room: room,
                    me: me,
                    // My own expense opens the editor; someone else's opens read-only details.
                    onTap: () {
                      if (mine) {
                        Get.toNamed(Routes.add, arguments: e);
                      } else {
                        showExpenseDetails(e, room, me);
                      }
                    },
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: mine
                        ? Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(
                          color: AppTheme.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final yes = await confirm(
                          'Delete expense?',
                          '${Money.fmt(e.amount)} will be removed for everyone.',
                          confirmText: 'Delete',
                          destructive: true,
                        );
                        if (yes) controller.deleteExpense(e);
                        return false; // the live stream removes the tile
                      },
                      child: tile,
                    )
                        : tile,
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  const _DayHeaderRow(this.h);
  final _DayHeader h;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(children: [
        Text(Fmt.dayLabel(h.date),
            style: TextStyle(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 13)),
        const Spacer(),
        Text(Money.fmt(h.total),
            style: TextStyle(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ]),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        Toast.ok('Room code copied');
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(Icons.key_rounded, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room code · share with friends',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              Text(code,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 4)),
            ],
          ),
        ),
        Icon(Icons.copy_rounded, color: cs.onSurfaceVariant, size: 20),
      ]),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.isMe,
    required this.left,
    required this.net,
  });
  final String name;
  final bool isMe;
  final bool left;
  final int net;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Avatar(name, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(isMe ? '$name (You)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (left)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
        ),
        NetText(net),
      ]),
    );
  }
}