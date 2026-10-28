import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/habits_screen.dart';
import '../../features/habit_detail/habit_detail_screen.dart';
import '../../features/habit_form/habit_form_screen.dart';
import '../../features/notes/note_editor_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/settings/archive_screen.dart';
import '../../features/settings/categories_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/feature_settings_screen.dart';
import '../../features/share/share_progress_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/tasks/task_form_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/tasks/task_analytics_screen.dart';
import 'routes.dart';

/// App-wide router instance.
final Provider<GoRouter> appRouterProvider =
    Provider<GoRouter>((Ref ref) => buildRouter());

/// Builds the route table. Dashboard and Notes live inside the shell (with the
/// bottom bar); everything else is full-screen on the root navigator.
///
/// Dashboard, Habits, Tasks and Notes live inside the shell. Form/detail routes
/// are full-screen above it. Order matters: `/habit/new` and `/note/new` must
/// be declared before the `:id` routes.
GoRouter buildRouter({String initialLocation = AppRoutes.dashboard}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell shell) =>
            AppShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (BuildContext c, GoRouterState s) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.habits, builder: (BuildContext c, GoRouterState s) => const HabitsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(path: AppRoutes.tasks, builder: (BuildContext c, GoRouterState s) => const TasksScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.notes,
                builder: (BuildContext c, GoRouterState s) =>
                    const NotesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.taskNew,
        builder: (BuildContext c, GoRouterState s) => const TaskFormScreen(),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (BuildContext c, GoRouterState s) => TaskDetailScreen(taskId: s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.taskAnalytics,
        builder: (BuildContext c, GoRouterState s) => const TaskAnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.habitNew,
        builder: (BuildContext c, GoRouterState s) => const HabitFormScreen(),
      ),
      GoRoute(
        path: '/habit/:id',
        builder: (BuildContext c, GoRouterState s) =>
            HabitDetailScreen(habitId: s.pathParameters['id'] ?? ''),
        routes: <RouteBase>[
          GoRoute(
            path: 'edit',
            builder: (BuildContext c, GoRouterState s) =>
                HabitFormScreen(habitId: s.pathParameters['id']),
          ),
          GoRoute(
            path: 'analytics',
            builder: (BuildContext c, GoRouterState s) =>
                AnalyticsScreen(habitId: s.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.analytics,
        builder: (BuildContext c, GoRouterState s) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.noteNewPath,
        builder: (BuildContext c, GoRouterState s) => NoteEditorScreen(
          habitId: s.uri.queryParameters['habit'],
        ),
      ),
      GoRoute(
        path: '/note/:id',
        builder: (BuildContext c, GoRouterState s) =>
            NoteEditorScreen(noteId: s.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext c, GoRouterState s) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.shareProgress,
        builder: (BuildContext c, GoRouterState s) => ShareProgressScreen(
          habitId: s.uri.queryParameters['habit'],
        ),
      ),
      GoRoute(
        path: AppRoutes.categories,
        builder: (BuildContext c, GoRouterState s) => const CategoriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.archive,
        builder: (BuildContext c, GoRouterState s) => const ArchiveScreen(),
      ),
      GoRoute(path: AppRoutes.theme, builder: (BuildContext c, GoRouterState s) => const FeatureSettingsScreen(kind: 'theme')),
      GoRoute(path: AppRoutes.layout, builder: (BuildContext c, GoRouterState s) => const FeatureSettingsScreen(kind: 'layout')),
      GoRoute(path: AppRoutes.widgets, builder: (BuildContext c, GoRouterState s) => const FeatureSettingsScreen(kind: 'widgets')),
      GoRoute(path: AppRoutes.general, builder: (BuildContext c, GoRouterState s) => const FeatureSettingsScreen(kind: 'general')),
      GoRoute(path: AppRoutes.rearrange, builder: (BuildContext c, GoRouterState s) => const FeatureSettingsScreen(kind: 'rearrange')),
    ],
  );
}

