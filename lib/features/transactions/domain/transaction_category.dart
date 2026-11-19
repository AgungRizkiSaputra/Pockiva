import 'package:flutter/material.dart';

enum TransactionType {
  saving('saving', 'Pemasukan / Tabungan'),
  expense('expense', 'Pengeluaran');

  const TransactionType(this.value, this.label);

  final String value;
  final String label;

  bool get isIncome => this == TransactionType.saving;
  bool get isExpense => this == TransactionType.expense;

  static TransactionType fromValue(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'saving' || lower == 'income' || lower == 'deposit') {
      return TransactionType.saving;
    }
    return TransactionType.expense;
  }
}

@immutable
class TransactionCategory {
  const TransactionCategory({
    required this.code,
    required this.label,
    required this.icon,
    required this.type,
  });

  final String code;
  final String label;
  final IconData icon;
  final TransactionType type;

  static const List<TransactionCategory> savingCategories = [
    TransactionCategory(
      code: 'main_goal',
      label: 'Target Utama',
      icon: Icons.flag_outlined,
      type: TransactionType.saving,
    ),
    TransactionCategory(
      code: 'daily_saving',
      label: 'Harian',
      icon: Icons.savings_outlined,
      type: TransactionType.saving,
    ),
    TransactionCategory(
      code: 'emergency_fund',
      label: 'Dana Darurat',
      icon: Icons.shield_outlined,
      type: TransactionType.saving,
    ),
    TransactionCategory(
      code: 'investment',
      label: 'Investasi',
      icon: Icons.trending_up_rounded,
      type: TransactionType.saving,
    ),
    TransactionCategory(
      code: 'bonus',
      label: 'Bonus',
      icon: Icons.card_giftcard_outlined,
      type: TransactionType.saving,
    ),
  ];

  static const List<TransactionCategory> expenseCategories = [
    TransactionCategory(
      code: 'food',
      label: 'Makanan',
      icon: Icons.restaurant_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'transport',
      label: 'Transportasi',
      icon: Icons.directions_transit_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'bills',
      label: 'Tagihan',
      icon: Icons.receipt_long_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'shopping',
      label: 'Belanja',
      icon: Icons.shopping_bag_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'entertainment',
      label: 'Hiburan',
      icon: Icons.movie_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'health',
      label: 'Kesehatan',
      icon: Icons.medical_services_outlined,
      type: TransactionType.expense,
    ),
    TransactionCategory(
      code: 'other',
      label: 'Lainnya',
      icon: Icons.category_outlined,
      type: TransactionType.expense,
    ),
  ];

  static List<TransactionCategory> forType(TransactionType type) =>
      type == TransactionType.saving ? savingCategories : expenseCategories;

  static TransactionCategory byCode(String code, {TransactionType? fallbackType}) {
    for (final cat in [...savingCategories, ...expenseCategories]) {
      if (cat.code == code) return cat;
    }
    if (fallbackType == TransactionType.saving) {
      return savingCategories.first;
    }
    return expenseCategories.last;
  }
}
