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
  static String date(DateTime d) => _full.format(d);
  static String short(DateTime d) => _short.format(d);
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class ExpenseCategory {
  const ExpenseCategory(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

const categories = <ExpenseCategory>[
  ExpenseCategory('food', 'Food', Icons.restaurant_rounded, Color(0xFFF97316)),
  ExpenseCategory('groceries', 'Groceries', Icons.shopping_basket_rounded, Color(0xFF16A34A)),
  ExpenseCategory('outing', 'Outing', Icons.celebration_rounded, Color(0xFFDB2777)),
  ExpenseCategory('transport', 'Transport', Icons.directions_bus_rounded, Color(0xFF2563EB)),
  ExpenseCategory('bills', 'Bills & Rent', Icons.receipt_long_rounded, Color(0xFF7C3AED)),
  ExpenseCategory('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFF0891B2)),
  ExpenseCategory('other', 'Other', Icons.category_rounded, Color(0xFF64748B)),
];

ExpenseCategory categoryOf(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.last);

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
