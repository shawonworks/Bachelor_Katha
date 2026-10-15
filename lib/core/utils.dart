import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';

/// All money is handled as integer paisa (1 taka = 100 paisa).
class Money {
  static String fmt(int paisa) {
    final abs = paisa.abs();
    final f = abs % 100 == 0 ? NumberFormat('#,##0') : NumberFormat('#,##0.00');
    return '৳${f.format(abs / 100)}';
  }

  static int? parse(String text) {
    final v = double.tryParse(text.trim().replaceAll(',', ''));
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }
}

class Fmt {
  static final _full = DateFormat('d MMM y');
  static final _short = DateFormat('d MMM');
  static final _dateTime = DateFormat('d MMM y, h:mm a');
  static final _month = DateFormat('MMMM y');

  static String date(DateTime d) => _full.format(d);
  static String short(DateTime d) => _short.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);
  static String month(DateTime d) => _month.format(d);
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Today / Yesterday / 12 Oct (adds the year when it is not the current year).
  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = DateTime.utc(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return d.year == now.year ? _short.format(d) : _full.format(d);
  }
}

class ExpenseCategory {
  const ExpenseCategory(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

/// Categories offered when adding an expense.
const categories = <ExpenseCategory>[
  ExpenseCategory('breakfast', 'Breakfast', Icons.free_breakfast_rounded, Color(0xFFF59E0B)),
  ExpenseCategory('lunch', 'Lunch', Icons.lunch_dining_rounded, Color(0xFFF97316)),
  ExpenseCategory('snacks', 'Evening Snacks', Icons.bakery_dining_rounded, Color(0xFFDB2777)),
  ExpenseCategory('dinner', 'Dinner', Icons.dinner_dining_rounded, Color(0xFF7C3AED)),
  ExpenseCategory('travel', 'Travel', Icons.directions_bus_rounded, Color(0xFF2563EB)),
  ExpenseCategory('lend', 'Lend', Icons.handshake_rounded, Color(0xFF0D9488)),
  ExpenseCategory('other', 'Others', Icons.category_rounded, Color(0xFF64748B)),
];

/// Old categories: no longer selectable, but old expenses still display correctly.
const _legacyCategories = <ExpenseCategory>[
  ExpenseCategory('food', 'Food', Icons.restaurant_rounded, Color(0xFFF97316)),
  ExpenseCategory('groceries', 'Groceries', Icons.shopping_basket_rounded, Color(0xFF16A34A)),
  ExpenseCategory('outing', 'Outing', Icons.celebration_rounded, Color(0xFFDB2777)),
  ExpenseCategory('transport', 'Transport', Icons.directions_bus_rounded, Color(0xFF2563EB)),
  ExpenseCategory('bills', 'Bills & Rent', Icons.receipt_long_rounded, Color(0xFF7C3AED)),
  ExpenseCategory('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFF0891B2)),
];

ExpenseCategory categoryOf(String id) {
  for (final c in categories) {
    if (c.id == id) return c;
  }
  for (final c in _legacyCategories) {
    if (c.id == id) return c;
  }
  return categories.last;
}

/// Sensible default category from the time of day.
String defaultCategoryNow() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 16) return 'lunch';
  if (h < 19) return 'snacks';
  return 'dinner';
}

class Toast {
  static String message(Object e) {
    if (e is String) return e;
    if (e is FirebaseException) {
      if (e.code == 'unavailable') return 'No internet connection.';
      if (e.code == 'permission-denied') return 'Permission denied.';
      return e.message ?? 'Something went wrong.';
    }
    return 'Something went wrong. Please try again.';
  }

  static void ok(String m) => _show(m, AppTheme.green);
  static void err(String m) => _show(m, AppTheme.red);
  static void error(Object e) => err(message(e));

  static void _show(String m, Color bg) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.rawSnackbar(
      message: m,
      backgroundColor: bg,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(milliseconds: 2500),
    );
  }
}