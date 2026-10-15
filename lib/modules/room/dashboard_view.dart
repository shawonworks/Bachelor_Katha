import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../core/app_theme.dart';
import '../../core/utils.dart';
import '../../widgets/app_widgets.dart';
import 'room_controller.dart';

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
              if (v == 'leave') controller.leave();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'leave', child: Text('Switch / leave room')),
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
          return const Center(child: CircularProgressIndicator());
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
                    SectionTitle('Members (${room.members.length})'),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          for (final id in room.ids)
                            _MemberRow(
                              name: room.nameOf(id),
                              isMe: id == me,
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
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final e = list[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
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
                      child: ExpenseTile(
                        expense: e,
                        room: room,
                        onTap: () => Get.toNamed(Routes.add, arguments: e),
                      ),
                    ),
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
  const _MemberRow({required this.name, required this.isMe, required this.net});
  final String name;
  final bool isMe;
  final int net;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Avatar(name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(isMe ? '$name (You)' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          NetText(net),
        ]),
      );
}
