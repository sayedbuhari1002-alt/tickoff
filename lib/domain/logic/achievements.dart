/// Streak milestones, in days. Free for everyone; no purchase checks.
const List<int> kMilestones = <int>[1, 7, 14, 30, 50, 100, 200, 365, 730];

class AchievementStatus {
  const AchievementStatus({
    required this.milestone,
    required this.unlocked,
    this.unlockedOn,
  });

  final int milestone;
  final bool unlocked;

  /// `yyyy-MM-dd` the milestone was first reached, when known.
  final String? unlockedOn;
}

class AchievementSummary {
  const AchievementSummary({
    required this.statuses,
    required this.bestStreak,
    required this.nextMilestone,
    required this.previousMilestone,
  });

  final List<AchievementStatus> statuses;
  final int bestStreak;

  /// Next locked milestone, or null when all are unlocked.
  final int? nextMilestone;

  /// Highest unlocked milestone (0 when none).
  final int previousMilestone;

  int get unlockedCount =>
      statuses.where((AchievementStatus s) => s.unlocked).length;

  /// 0..1 progress from the previous milestone to the next one.
  double get progressToNext {
    final int? next = nextMilestone;
    if (next == null) return 1;
    final int span = next - previousMilestone;
    if (span <= 0) return 1;
    final double p = (bestStreak - previousMilestone) / span;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }
}

/// Milestones newly reached by [bestStreak] that are not in [alreadyUnlocked].
List<int> newlyReached(int bestStreak, Iterable<int> alreadyUnlocked) {
  final Set<int> have = alreadyUnlocked.toSet();
  return kMilestones
      .where((int m) => bestStreak >= m && !have.contains(m))
      .toList();
}

/// Builds the locked/unlocked list. A milestone is unlocked when it was stored
/// as unlocked (history is kept even if streak data is later edited) or when
/// [bestStreak] already reaches it.
///
/// [AchievementSummary.nextMilestone] is the lowest locked milestone and
/// [AchievementSummary.previousMilestone] the highest unlocked one below it.
AchievementSummary summarizeAchievements({
  required int bestStreak,
  required Map<int, String> unlockedOn,
}) {
  final List<AchievementStatus> statuses = <AchievementStatus>[];
  for (final int m in kMilestones) {
    statuses.add(
      AchievementStatus(
        milestone: m,
        unlocked: unlockedOn.containsKey(m) || bestStreak >= m,
        unlockedOn: unlockedOn[m],
      ),
    );
  }
  int? next;
  for (final AchievementStatus s in statuses) {
    if (!s.unlocked) {
      next = s.milestone;
      break;
    }
  }
  int previous = 0;
  for (final AchievementStatus s in statuses) {
    if (s.unlocked && (next == null || s.milestone < next) && s.milestone > previous) {
      previous = s.milestone;
    }
  }
  return AchievementSummary(
    statuses: statuses,
    bestStreak: bestStreak,
    nextMilestone: next,
    previousMilestone: previous,
  );
}
