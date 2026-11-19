import 'package:flutter/foundation.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/domain/transaction_item.dart';

@immutable
class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.monthKey,
    required this.savings,
    required this.expenses,
  });

  /// Format: YYYY-MM
  final String monthKey;
  final double savings;
  final double expenses;

  double get net => savings - expenses;

  factory MonthlyTrendPoint.fromJson(Map<String, dynamic> json) {
    return MonthlyTrendPoint(
      monthKey: json['month'] as String,
      savings: _toDouble(json['savings']),
      expenses: _toDouble(json['expenses']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

@immutable
class CategorySummary {
  const CategorySummary({
    required this.categoryCode,
    required this.type,
    required this.total,
    required this.count,
    required this.share,
  });

  final String categoryCode;
  final TransactionType type;
  final double total;
  final int count;
  final double share;

  TransactionCategory get info =>
      TransactionCategory.byCode(categoryCode, fallbackType: type);
}

@immutable
class BudgetInsightItem {
  const BudgetInsightItem({
    required this.title,
    required this.detail,
    required this.isPositive,
  });

  final String title;
  final String detail;
  final bool isPositive;
}

@immutable
class FinancialSummary {
  const FinancialSummary({
    required this.totalSavings,
    required this.totalExpenses,
    double? totalBalance,
    required this.monthSavings,
    required this.monthExpenses,
    required this.monthlyTrends,
    required this.expenseCategories,
    required this.savingCategories,
  }) : totalBalance = totalBalance ?? (totalSavings - totalExpenses);

  final double totalSavings;
  final double totalExpenses;
  final double totalBalance;
  final double monthSavings;
  final double monthExpenses;
  final List<MonthlyTrendPoint> monthlyTrends;
  final List<CategorySummary> expenseCategories;
  final List<CategorySummary> savingCategories;

  double get monthNet => monthSavings - monthExpenses;
  double get totalIncome => totalSavings;

  static const FinancialSummary empty = FinancialSummary(
    totalSavings: 0,
    totalExpenses: 0,
    totalBalance: 0,
    monthSavings: 0,
    monthExpenses: 0,
    monthlyTrends: [],
    expenseCategories: [],
    savingCategories: [],
  );

  double progressRatio(double savingsTarget) {
    if (savingsTarget <= 0) return 0;
    final available = totalBalance > 0 ? totalBalance : 0.0;
    return (available / savingsTarget).clamp(0.0, 1.0);
  }

  double progressPercentage(double savingsTarget) {
    if (savingsTarget <= 0) return 0;
    final available = totalBalance > 0 ? totalBalance : 0.0;
    return (available / savingsTarget) * 100;
  }

  double remainingToTarget(double savingsTarget) {
    if (savingsTarget <= 0) return 0;
    final available = totalBalance > 0 ? totalBalance : 0.0;
    final rem = savingsTarget - available;
    return rem > 0 ? rem : 0;
  }

  /// Derives real, non-fabricated insights strictly from actual user numbers.
  List<BudgetInsightItem> deriveInsights({
    required double savingsTarget,
    DateTime? targetDeadline,
    DateTime? now,
  }) {
    final insights = <BudgetInsightItem>[];
    final totalMonthFlow = monthSavings + monthExpenses;

    if (totalMonthFlow > 0) {
      final savingRate = (monthSavings / totalMonthFlow) * 100;
      insights.add(
        BudgetInsightItem(
          title: 'Rasio menabung bulan ini ${savingRate.toStringAsFixed(0)}%',
          detail: savingRate >= 20
              ? 'Porsi tabungan bulan ini melampaui patokan sehat 20% dari arus kas tercatat.'
              : 'Sisihkan sedikit lebih banyak di kategori tabungan untuk mendekati patokan 20%.',
          isPositive: savingRate >= 20,
        ),
      );
    }

    if (expenseCategories.isNotEmpty) {
      final top = expenseCategories.first;
      final pct = (top.share * 100).toStringAsFixed(0);
      insights.add(
        BudgetInsightItem(
          title: 'Pengeluaran terbesar: ${top.info.label} ($pct%)',
          detail:
              'Tercatat ${top.count} transaksi di kategori ${top.info.label} sepanjang bulan ini.',
          isPositive: top.share < 0.45,
        ),
      );
    }

    if (monthlyTrends.length >= 2) {
      final current = monthlyTrends.last;
      final prev = monthlyTrends[monthlyTrends.length - 2];
      if (prev.expenses > 0 && current.expenses > 0) {
        final deltaPct =
            ((current.expenses - prev.expenses) / prev.expenses) * 100;
        if (deltaPct <= -5) {
          insights.add(
            BudgetInsightItem(
              title:
                  'Pengeluaran turun ${deltaPct.abs().toStringAsFixed(0)}% dari bulan lalu',
              detail: 'Disiplin anggaranmu membaik dibanding periode sebelumnya.',
              isPositive: true,
            ),
          );
        } else if (deltaPct >= 10) {
          insights.add(
            BudgetInsightItem(
              title:
                  'Pengeluaran naik ${deltaPct.toStringAsFixed(0)}% dari bulan lalu',
              detail:
                  'Periksa kategori dengan lonjakan tertinggi agar target tabungan tetap aman.',
              isPositive: false,
            ),
          );
        }
      }
    }

    if (savingsTarget > 0 && totalBalance < savingsTarget && targetDeadline != null) {
      final ref = now ?? DateTime.now();
      final daysLeft = targetDeadline.difference(DateTime(ref.year, ref.month, ref.day)).inDays;
      if (daysLeft > 0) {
        final available = totalBalance > 0 ? totalBalance : 0.0;
        final perDay = (savingsTarget - available) / daysLeft;
        insights.add(
          BudgetInsightItem(
            title: 'Sisa $daysLeft hari menuju tenggat target',
            detail:
                'Rata-rata setoran Rp ${perDay.ceil().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}/hari dibutuhkan untuk mencapai 100%.',
            isPositive: true,
          ),
        );
      }
    }

    return insights;
  }

  /// Pure deterministic calculator from a list of transactions (used offline & in tests).
  factory FinancialSummary.fromTransactions(
    List<TransactionItem> transactions, {
    int months = 6,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final currentMonthStart = DateTime(ref.year, ref.month, 1);

    double totalSavings = 0;
    double totalExpenses = 0;
    double monthSavings = 0;
    double monthExpenses = 0;

    final monthKeys = <String>[];
    final monthSavMap = <String, double>{};
    final monthExpMap = <String, double>{};

    for (int i = months - 1; i >= 0; i--) {
      final dt = DateTime(ref.year, ref.month - i, 1);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      monthKeys.add(key);
      monthSavMap[key] = 0;
      monthExpMap[key] = 0;
    }

    final expCatTotals = <String, double>{};
    final expCatCounts = <String, int>{};
    final savCatTotals = <String, double>{};
    final savCatCounts = <String, int>{};

    for (final tx in transactions) {
      final mKey =
          '${tx.occurredAt.year}-${tx.occurredAt.month.toString().padLeft(2, '0')}';
      final isThisMonth = !tx.occurredAt.isBefore(currentMonthStart);

      if (tx.isSaving) {
        totalSavings += tx.amount;
        if (monthSavMap.containsKey(mKey)) {
          monthSavMap[mKey] = monthSavMap[mKey]! + tx.amount;
        }
        if (isThisMonth) {
          monthSavings += tx.amount;
          savCatTotals[tx.category] = (savCatTotals[tx.category] ?? 0) + tx.amount;
          savCatCounts[tx.category] = (savCatCounts[tx.category] ?? 0) + 1;
        }
      } else {
        totalExpenses += tx.amount;
        if (monthExpMap.containsKey(mKey)) {
          monthExpMap[mKey] = monthExpMap[mKey]! + tx.amount;
        }
        if (isThisMonth) {
          monthExpenses += tx.amount;
          expCatTotals[tx.category] = (expCatTotals[tx.category] ?? 0) + tx.amount;
          expCatCounts[tx.category] = (expCatCounts[tx.category] ?? 0) + 1;
        }
      }
    }

    final trends = monthKeys
        .map(
          (k) => MonthlyTrendPoint(
            monthKey: k,
            savings: monthSavMap[k] ?? 0,
            expenses: monthExpMap[k] ?? 0,
          ),
        )
        .toList();

    List<CategorySummary> buildCatList(
      Map<String, double> totals,
      Map<String, int> counts,
      double grandTotal,
      TransactionType type,
    ) {
      final list = totals.entries
          .map(
            (e) => CategorySummary(
              categoryCode: e.key,
              type: type,
              total: e.value,
              count: counts[e.key] ?? 0,
              share: grandTotal > 0 ? e.value / grandTotal : 0,
            ),
          )
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));
      return list;
    }

    return FinancialSummary(
      totalSavings: totalSavings,
      totalExpenses: totalExpenses,
      totalBalance: totalSavings - totalExpenses,
      monthSavings: monthSavings,
      monthExpenses: monthExpenses,
      monthlyTrends: trends,
      expenseCategories: buildCatList(
        expCatTotals,
        expCatCounts,
        monthExpenses,
        TransactionType.expense,
      ),
      savingCategories: buildCatList(
        savCatTotals,
        savCatCounts,
        monthSavings,
        TransactionType.saving,
      ),
    );
  }

  /// Parses the JSONB returned by `public.get_financial_summary` RPC.
  factory FinancialSummary.fromRpcJson(Map<String, dynamic> json) {
    final rawTrends = (json['monthly_trends'] as List<dynamic>? ?? const []);
    final trends = rawTrends
        .whereType<Map<String, dynamic>>()
        .map(MonthlyTrendPoint.fromJson)
        .toList();

    final totalSavings = MonthlyTrendPoint._toDouble(json['total_savings']);
    final totalExpenses = MonthlyTrendPoint._toDouble(json['total_expenses']);
    final totalBalance = json['total_balance'] != null
        ? MonthlyTrendPoint._toDouble(json['total_balance'])
        : (totalSavings - totalExpenses);

    final monthExpenses = MonthlyTrendPoint._toDouble(json['month_expenses']);
    final monthSavings = MonthlyTrendPoint._toDouble(json['month_savings']);

    final rawCats = (json['category_breakdown'] as List<dynamic>? ?? const []);
    final expCats = <CategorySummary>[];
    final savCats = <CategorySummary>[];

    for (final item in rawCats.whereType<Map<String, dynamic>>()) {
      final type = TransactionType.fromValue((item['type'] as String?) ?? 'expense');
      final total = MonthlyTrendPoint._toDouble(item['total']);
      final count = (item['count'] as num?)?.toInt() ?? 0;
      final denom = type == TransactionType.saving ? monthSavings : monthExpenses;
      final summary = CategorySummary(
        categoryCode: (item['category'] as String?) ?? 'other',
        type: type,
        total: total,
        count: count,
        share: denom > 0 ? total / denom : 0,
      );
      if (type == TransactionType.saving) {
        savCats.add(summary);
      } else {
        expCats.add(summary);
      }
    }

    expCats.sort((a, b) => b.total.compareTo(a.total));
    savCats.sort((a, b) => b.total.compareTo(a.total));

    return FinancialSummary(
      totalSavings: totalSavings,
      totalExpenses: totalExpenses,
      totalBalance: totalBalance,
      monthSavings: monthSavings,
      monthExpenses: monthExpenses,
      monthlyTrends: trends,
      expenseCategories: expCats,
      savingCategories: savCats,
    );
  }
}
