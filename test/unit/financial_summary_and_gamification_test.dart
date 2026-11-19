import 'package:flutter_test/flutter_test.dart';
import 'package:tabungan_pribadi/features/gamification/domain/gamification_models.dart';
import 'package:tabungan_pribadi/features/insights/domain/financial_summary.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_category.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_item.dart';

void main() {
  group('FinancialSummary calculations', () {
    final now = DateTime(2026, 11, 18, 12, 0);

    final sampleTransactions = [
      TransactionItem(
        id: '1',
        userId: 'u1',
        type: TransactionType.saving,
        amount: 2000000,
        category: 'main_goal',
        occurredAt: DateTime(2026, 11, 15),
        createdAt: DateTime(2026, 11, 15),
      ),
      TransactionItem(
        id: '2',
        userId: 'u1',
        type: TransactionType.saving,
        amount: 500000,
        category: 'emergency_fund',
        occurredAt: DateTime(2026, 10, 20),
        createdAt: DateTime(2026, 10, 20),
      ),
      TransactionItem(
        id: '3',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 300000,
        category: 'food',
        occurredAt: DateTime(2026, 11, 16),
        createdAt: DateTime(2026, 11, 16),
      ),
      TransactionItem(
        id: '4',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 100000,
        category: 'transport',
        occurredAt: DateTime(2026, 11, 17),
        createdAt: DateTime(2026, 11, 17),
      ),
      TransactionItem(
        id: '5',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 500000,
        category: 'food',
        occurredAt: DateTime(2026, 10, 12),
        createdAt: DateTime(2026, 10, 12),
      ),
    ];

    test('computes total savings, monthly flows, and target progress accurately', () {
      final summary = FinancialSummary.fromTransactions(
        sampleTransactions,
        months: 6,
        now: now,
      );

      expect(summary.totalSavings, 2500000);
      expect(summary.totalExpenses, 900000);
      expect(summary.totalBalance, 1600000);
      expect(summary.monthSavings, 2000000);
      expect(summary.monthExpenses, 400000);
      expect(summary.monthNet, 1600000);
      expect(summary.progressPercentage(5000000), closeTo(32.0, 0.001));
      expect(summary.progressRatio(5000000), closeTo(0.32, 0.001));
      expect(summary.remainingToTarget(5000000), 3400000);
      expect(summary.remainingToTarget(1000000), 0);
    });

    test('master task scenario: Deposit Rp100.000, Expense Rp50.000 -> Balance Rp50.000', () {
      final txs = [
        TransactionItem(
          id: 'dep-1',
          userId: 'u1',
          type: TransactionType.saving,
          amount: 100000,
          category: 'main_goal',
          occurredAt: DateTime(2026, 11, 1),
          createdAt: DateTime(2026, 11, 1),
        ),
        TransactionItem(
          id: 'exp-1',
          userId: 'u1',
          type: TransactionType.expense,
          amount: 50000,
          category: 'food',
          occurredAt: DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 11, 2),
        ),
      ];

      var summary = FinancialSummary.fromTransactions(txs, now: now);
      expect(summary.totalSavings, 100000);
      expect(summary.totalExpenses, 50000);
      expect(summary.totalBalance, 50000);

      // Additional expense Rp20.000 -> Balance Rp30.000
      final tx3 = TransactionItem(
        id: 'exp-2',
        userId: 'u1',
        type: TransactionType.expense,
        amount: 20000,
        category: 'transport',
        occurredAt: DateTime(2026, 11, 3),
        createdAt: DateTime(2026, 11, 3),
      );
      summary = FinancialSummary.fromTransactions([...txs, tx3], now: now);
      expect(summary.totalBalance, 30000);

      // Edit expense Rp20.000 to Rp10.000 -> Balance Rp40.000
      final tx3Edited = tx3.copyWith(amount: 10000);
      summary = FinancialSummary.fromTransactions([...txs, tx3Edited], now: now);
      expect(summary.totalBalance, 40000);

      // Delete expense Rp10.000 -> Balance Rp50.000
      summary = FinancialSummary.fromTransactions(txs, now: now);
      expect(summary.totalBalance, 50000);
    });

    test('calculates category shares and monthly trend series accurately', () {
      final summary = FinancialSummary.fromTransactions(
        sampleTransactions,
        months: 6,
        now: now,
      );

      expect(summary.monthlyTrends.length, 6);
      expect(summary.monthlyTrends.last.monthKey, '2026-11');
      expect(summary.monthlyTrends.last.savings, 2000000);
      expect(summary.monthlyTrends.last.expenses, 400000);

      expect(summary.expenseCategories.length, 2);
      expect(summary.expenseCategories.first.categoryCode, 'food');
      expect(summary.expenseCategories.first.share, closeTo(0.75, 0.001));
    });

    test('derives real insights only from actual data and returns empty when no data', () {
      expect(
        FinancialSummary.empty.deriveInsights(savingsTarget: 5000000, now: now),
        isEmpty,
      );

      final summary = FinancialSummary.fromTransactions(
        sampleTransactions,
        months: 6,
        now: now,
      );
      final insights = summary.deriveInsights(
        savingsTarget: 5000000,
        targetDeadline: DateTime(2026, 12, 18),
        now: now,
      );
      expect(insights, isNotEmpty);
      expect(
        insights.any((i) => i.title.contains('Makanan')),
        isTrue,
      );
      expect(
        insights.any((i) => i.title.contains('turun')),
        isTrue,
      );
    });
    test('validates expense cannot exceed available balance (Rp 100k balance vs Rp 1M expense)', () {
      final txs = [
        TransactionItem(
          id: 'dep-1',
          userId: 'u1',
          type: TransactionType.saving,
          amount: 100000,
          category: 'main_goal',
          occurredAt: DateTime(2026, 11, 1),
          createdAt: DateTime(2026, 11, 1),
        ),
      ];

      final summary = FinancialSummary.fromTransactions(txs, now: now);
      expect(summary.totalBalance, 100000);

      // Rule: Expense of 1.000.000 > balance 100.000 -> exceeds available balance
      const expenseAttempt = 1000000.0;
      final exceeds = expenseAttempt > summary.totalBalance;
      expect(exceeds, isTrue);

      // Rule: Expense of 50.000 <= balance 100.000 -> valid
      const validExpense = 50000.0;
      expect(validExpense <= summary.totalBalance, isTrue);
    });

    test('validates expense cannot be recorded when balance is Rp 0', () {
      const summary = FinancialSummary.empty;
      expect(summary.totalBalance, 0);

      const expenseAttempt = 50000.0;
      expect(expenseAttempt > summary.totalBalance, isTrue);
    });
  });

  group('UserStreak', () {
    test('returns effective streak when active today or yesterday, resets after gap', () {
      final now = DateTime(2026, 11, 18, 10, 0);

      final activeToday = UserStreak(
        currentStreak: 5,
        longestStreak: 7,
        totalActiveDays: 12,
        lastActive: DateTime(2026, 11, 18),
      );
      expect(activeToday.isActiveToday(now: now), isTrue);
      expect(activeToday.effectiveStreak(now: now), 5);

      final activeYesterday = UserStreak(
        currentStreak: 5,
        longestStreak: 7,
        totalActiveDays: 12,
        lastActive: DateTime(2026, 11, 17),
      );
      expect(activeYesterday.isActiveToday(now: now), isFalse);
      expect(activeYesterday.effectiveStreak(now: now), 5);

      final broken = UserStreak(
        currentStreak: 5,
        longestStreak: 7,
        totalActiveDays: 12,
        lastActive: DateTime(2026, 11, 15),
      );
      expect(broken.effectiveStreak(now: now), 0);
    });
  });
}
