/// Every route path in one place.
class AppRoutes {
  AppRoutes._();

  // Bottom-navigation tabs (inside the shell)
  static const String dashboard = '/dashboard';
  static const String habits = '/habits';
  static const String notes = '/notes';
  static const String tasks = '/tasks';
  static const String taskNew = '/task/new';
  static String taskDetail(String id) => '/task/$id';
  static const String taskAnalytics = '/task-analytics';

  // Habits (full-screen, no bottom bar)
  static const String habitNew = '/habit/new';
  static String habitDetail(String id) => '/habit/$id';
  static String habitEdit(String id) => '/habit/$id/edit';
  static String habitAnalytics(String id) => '/habit/$id/analytics';

  // Analytics across all habits
  static const String analytics = '/analytics';

  // Notes
  static const String noteNewPath = '/note/new';
  static String noteNew({String? habitId}) =>
      habitId == null ? noteNewPath : '$noteNewPath?habit=$habitId';
  static String noteEdit(String id) => '/note/$id';

  // Settings
  static const String settings = '/settings';
  static const String shareProgress = '/settings/share-progress';
  static String shareProgressFor(String habitId) =>
      '$shareProgress?habit=$habitId';
  static const String theme = '/settings/theme';
  static const String layout = '/settings/layout';
  static const String widgets = '/settings/widgets';
  static const String general = '/settings/general';
  static const String rearrange = '/settings/rearrange';
  static const String categories = '/settings/categories';
  static const String archive = '/settings/archive';
}
