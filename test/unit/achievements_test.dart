import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/domain/logic/achievements.dart';

void main() {
  test('milestones are the nine required values', () {
    expect(kMilestones, <int>[1, 7, 14, 30, 50, 100, 200, 365, 730]);
  });

  group('newlyReached', () {
    test('nothing before the first day', () {
      expect(newlyReached(0, const <int>[]), isEmpty);
    });

    test('everything up to the best streak that is not yet stored', () {
      expect(newlyReached(8, const <int>[]), <int>[1, 7]);
      expect(newlyReached(8, const <int>[1]), <int>[7]);
      expect(newlyReached(8, const <int>[1, 7]), isEmpty);
    });

    test('a very long streak reaches all nine', () {
      expect(newlyReached(1000, const <int>[]).length, 9);
    });
  });

  group('summarizeAchievements', () {
    test('locked and unlocked flags follow the best streak', () {
      final AchievementSummary s = summarizeAchievements(
        bestStreak: 10,
        unlockedOn: const <int, String>{},
      );
      expect(
        s.statuses.where((AchievementStatus a) => a.unlocked).map((AchievementStatus a) => a.milestone),
        <int>[1, 7],
      );
      expect(s.unlockedCount, 2);
      expect(s.nextMilestone, 14);
      expect(s.previousMilestone, 7);
      expect(s.progressToNext, closeTo(3 / 7, 1e-9));
    });

    test('no streak: first milestone is next with zero progress', () {
      final AchievementSummary s = summarizeAchievements(
        bestStreak: 0,
        unlockedOn: const <int, String>{},
      );
      expect(s.nextMilestone, 1);
      expect(s.previousMilestone, 0);
      expect(s.progressToNext, 0);
    });

    test('everything unlocked has no next milestone', () {
      final AchievementSummary s = summarizeAchievements(
        bestStreak: 800,
        unlockedOn: const <int, String>{},
      );
      expect(s.unlockedCount, 9);
      expect(s.nextMilestone, isNull);
      expect(s.progressToNext, 1);
    });

    test('stored unlocks are kept even if the streak data later shrinks', () {
      final AchievementSummary s = summarizeAchievements(
        bestStreak: 0,
        unlockedOn: const <int, String>{30: '2026-10-01'},
      );
      final AchievementStatus thirty =
          s.statuses.firstWhere((AchievementStatus a) => a.milestone == 30);
      expect(thirty.unlocked, isTrue);
      expect(thirty.unlockedOn, '2026-10-01');
      expect(s.nextMilestone, 1);
    });
  });
}
