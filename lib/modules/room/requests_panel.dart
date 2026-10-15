import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';
import '../../widgets/app_widgets.dart';
import 'room_controller.dart';

/// Approval cards: requests that need my answer, and the status of my own requests.
class RequestsPanel extends GetView<RoomController> {
  const RequestsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final room = controller.room.value;
      if (room == null) return const SizedBox.shrink();
      final respond = controller.toRespond;
      final mine = controller.mine;
      if (respond.isEmpty && mine.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          const SizedBox(height: 14),
          for (final r in respond)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RespondCard(r: r, c: controller),
            ),
          for (final r in mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MineCard(r: r, c: controller, room: room),
            ),
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.color, required this.title});
  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) => Row(children: [
    CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, size: 20, color: color),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    ),
  ]);
}

class _RespondCard extends StatelessWidget {
  const _RespondCard({required this.r, required this.c});
  final RoomRequest r;
  final RoomController c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Obx(() {
        final busy = c.busy.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              icon: r.isLeave ? Icons.logout_rounded : Icons.lock_reset_rounded,
              color: const Color(0xFFF59E0B),
              title: r.isLeave
                  ? '${r.byName} wants to leave'
                  : '${r.byName} wants to close the account',
            ),
            const SizedBox(height: 10),
            Text(c.approverMessage(r),
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.red,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: busy ? null : () => c.respond(r, false),
                  child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: busy ? null : () => c.respond(r, true),
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        );
      }),
    );
  }
}

class _MineCard extends StatelessWidget {
  const _MineCard({required this.r, required this.c, required this.room});
  final RoomRequest r;
  final RoomController c;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final what = r.isLeave ? 'leave' : 'close';

    if (r.isApproved) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(
            icon: Icons.check_circle_rounded,
            color: AppTheme.green,
            title: 'Everyone approved your request',
          ),
          const SizedBox(height: 12),
          AppButton(
            label: r.isLeave ? 'Leave room now' : 'Close account now',
            icon: r.isLeave ? Icons.logout_rounded : Icons.lock_reset_rounded,
            color: AppTheme.green,
            onPressed: () => r.isLeave ? c.finishLeave() : c.finishClose(r),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => c.cancelRequest(r),
              child: const Text('Not now, cancel request'),
            ),
          ),
        ]),
      );
    }

    if (r.isDeclined) {
      final who = room.nameOf(r.declinedBy);
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(
            icon: Icons.block_rounded,
            color: AppTheme.red,
            title: '$who declined your request to $what',
          ),
          const SizedBox(height: 8),
          Text(
            r.isLeave
                ? 'Settle up with $who first, then send the request again.'
                : '$who wants to review the expenses first. Talk it over, then request again.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => c.cancelRequest(r),
              child: const Text('Dismiss'),
            ),
          ),
        ]),
      );
    }

    // Pending
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Header(
          icon: Icons.hourglass_top_rounded,
          color: const Color(0xFFF59E0B),
          title: r.isLeave ? 'Leave request pending' : 'Close request pending',
        ),
        const SizedBox(height: 10),
        for (final a in r.approvers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(
                r.approvals[a] == 'approved'
                    ? Icons.check_circle_rounded
                    : Icons.schedule_rounded,
                size: 18,
                color: r.approvals[a] == 'approved' ? AppTheme.green : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(room.nameOf(a), style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(r.approvals[a] == 'approved' ? 'Approved' : 'Waiting',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ]),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => c.cancelRequest(r),
            child: const Text('Cancel request'),
          ),
        ),
      ]),
    );
  }
}