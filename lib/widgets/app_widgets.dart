import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../core/app_theme.dart';
import '../core/utils.dart';
import '../data/models.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? cs.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.tonal = false,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool tonal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(
          strokeWidth: 2.5, color: tonal ? cs.primary : cs.onPrimary),
    )
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: color,
    );
    final action = loading ? null : onPressed;
    return tonal
        ? FilledButton.tonal(onPressed: action, style: style, child: child)
        : FilledButton(onPressed: action, style: style, child: child);
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.prefixText,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.action,
    this.textStyle,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  /// For multi-line fields (e.g. notes): text wraps to the next line and the
  /// box grows from [minLines] up to [maxLines], then scrolls inside.
  final int? minLines;
  final int? maxLines;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? action;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    OutlineInputBorder border([Color? c, double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: w),
    );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: capitalization,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      textInputAction: action,
      validator: validator,
      style: textStyle,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        prefixText: prefixText,
        counterText: '',
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(cs.primary, 1.6),
        errorBorder: border(cs.error, 1.2),
        focusedErrorBorder: border(cs.error, 1.6),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;
  static const _colors = [
    Color(0xFF6366F1), Color(0xFF0EA5E9), Color(0xFF10B981), Color(0xFFF59E0B),
    Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final c = _colors[seed % _colors.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.withValues(alpha: 0.16),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: size * 0.42),
      ),
    );
  }
}

/// "gets ৳x" / "owes ৳x" / "settled" label, colored.
class NetText extends StatelessWidget {
  const NetText(this.net, {super.key, this.big = false});
  final int net;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = net > 0 ? AppTheme.green : net < 0 ? AppTheme.red : cs.onSurfaceVariant;
    final text = net > 0
        ? 'gets ${Money.fmt(net)}'
        : net < 0
        ? 'owes ${Money.fmt(net)}'
        : 'settled';
    return Text(text,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: big ? 16 : 14));
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.net, required this.total, required this.since});
  final int net;
  final int total;
  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final colors = net > 0
        ? const [Color(0xFF047857), Color(0xFF10B981)]
        : net < 0
        ? const [Color(0xFFBE123C), Color(0xFFFB7185)]
        : const [Color(0xFF4338CA), Color(0xFF7C3AED)];
    final label = net > 0 ? 'You will get' : net < 0 ? 'You need to pay' : 'All settled up';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(Money.fmt(net.abs()),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 38)),
          const SizedBox(height: 18),
          Row(children: [
            _Stat('Total spent', Money.fmt(total)),
            _Stat('Since', Fmt.date(since)),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    ),
  );
}

/// One expense row: category icon, note/category, who paid, total amount and
/// what it means for [me] (you get / you owe / not involved).
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.room,
    required this.me,
    this.onTap,
  });
  final Expense expense;
  final Room room;
  final String me;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = expense;
    final cat = categoryOf(e.category);
    final hasNote = e.title.isNotEmpty;
    final title = hasNote ? e.title : cat.label;
    String name(String id) => id == me ? 'You' : room.nameOf(id);

    final String sub;
    if (e.isLend && e.split.length == 1) {
      sub = '${name(e.paidBy)} lent to ${name(e.split.first)}';
    } else {
      final paid = e.paidBy == me ? 'You paid' : 'Paid by ${room.nameOf(e.paidBy)}';
      sub = hasNote ? '${cat.label} · $paid' : paid;
    }

    final addedBy = e.createdBy != me && e.createdBy != e.paidBy
        ? 'Added by ${room.nameOf(e.createdBy)}'
        : null;

    final impact = e.impactOn(me);
    final involved = e.paidBy == me || e.shareMap.containsKey(me);
    final String impactText;
    final Color impactColor;
    if (impact > 0) {
      impactText = 'You get ${Money.fmt(impact)}';
      impactColor = AppTheme.green;
    } else if (impact < 0) {
      impactText = 'You owe ${Money.fmt(impact)}';
      impactColor = AppTheme.red;
    } else {
      impactText = involved ? 'No balance change' : 'Not involved';
      impactColor = cs.onSurfaceVariant;
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cat.color.withValues(alpha: 0.15),
            child: Icon(cat.icon, color: cat.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                if (addedBy != null)
                  Text(addedBy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Money.fmt(e.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 3),
              Text(impactText,
                  style: TextStyle(
                      color: impactColor, fontWeight: FontWeight.w700, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pulsing placeholder shown while data loads.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, required this.height, this.radius = 10});
  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_c),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A list of skeleton cards.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(children: [
              AppSkeleton(width: 44, height: 44, radius: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AppSkeleton(width: 140, height: 14),
                  SizedBox(height: 8),
                  AppSkeleton(width: 90, height: 11),
                ]),
              ),
              AppSkeleton(width: 56, height: 16),
            ]),
          ),
        ),
    ],
  );
}

Future<bool> confirm(
    String title,
    String message, {
      String confirmText = 'Confirm',
      bool destructive = false,
    }) async {
  final r = await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppTheme.red) : null,
          onPressed: () => Get.back(result: true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return r ?? false;
}