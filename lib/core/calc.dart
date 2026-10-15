import 'dart:math';

import '../data/models.dart';

class Stats {
  const Stats(this.paid, this.share, this.net);
  final Map<String, int> paid;
  final Map<String, int> share;
  final Map<String, int> net;
  int get total => paid.values.fold(0, (a, b) => a + b);
}

/// net = opening + paid - share (all in paisa, remainder paisa distributed deterministically).
Stats computeStats(
    Iterable<String> ids,
    Iterable<Expense> expenses, {
      Map<String, int> opening = const {},
    }) {
  final paid = {for (final i in ids) i: 0};
  final share = {for (final i in ids) i: 0};
  for (final e in expenses) {
    paid[e.paidBy] = (paid[e.paidBy] ?? 0) + e.amount;
    if (e.isCustom) {
      // Custom split: exact amounts per person.
      e.shares.forEach((id, v) => share[id] = (share[id] ?? 0) + v);
      continue;
    }
    final s = [...e.split]..sort();
    if (s.isEmpty) continue;
    final base = e.amount ~/ s.length;
    var rem = e.amount - base * s.length;
    for (final id in s) {
      final extra = rem > 0 ? 1 : 0;
      rem -= extra;
      share[id] = (share[id] ?? 0) + base + extra;
    }
  }
  final keys = {...paid.keys, ...share.keys};
  final net = {
    for (final k in keys) k: (opening[k] ?? 0) + (paid[k] ?? 0) - (share[k] ?? 0),
  };
  return Stats(paid, share, net);
}

class Transfer {
  const Transfer(this.from, this.to, this.amount);
  final String from;
  final String to;
  final int amount;
}

class _P {
  _P(this.id, this.amt);
  final String id;
  int amt;
}

/// Greedy minimal-transfer settlement suggestion.
List<Transfer> suggestTransfers(Map<String, int> net) {
  final debtors = [for (final e in net.entries) if (e.value < 0) _P(e.key, -e.value)]
    ..sort((a, b) => b.amt.compareTo(a.amt));
  final creditors = [for (final e in net.entries) if (e.value > 0) _P(e.key, e.value)]
    ..sort((a, b) => b.amt.compareTo(a.amt));
  final out = <Transfer>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final x = min(debtors[i].amt, creditors[j].amt);
    out.add(Transfer(debtors[i].id, creditors[j].id, x));
    debtors[i].amt -= x;
    creditors[j].amt -= x;
    if (debtors[i].amt == 0) i++;
    if (creditors[j].amt == 0) j++;
  }
  return out;
}