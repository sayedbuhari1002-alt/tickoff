import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../shared/widgets/widgets.dart';

/// Hosts the four bottom-navigation destinations and the shared create button.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: TickoffBottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: (int index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onAdd: () => _showCreateChoices(context),
      ),
    );
  }
}


Future<void> _showCreateChoices(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text('Create new', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
          ListTile(leading: const Icon(Icons.check_circle_outline_rounded), title: const Text('Add Habit'), subtitle: const Text('Create a habit and schedule its tracking'), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(sheetContext); context.push(AppRoutes.habitNew); }),
          ListTile(leading: const Icon(Icons.add_task_rounded), title: const Text('Add Task'), subtitle: const Text('Create a task with deadline, reminder and subtasks'), trailing: const Icon(Icons.chevron_right), onTap: () { Navigator.pop(sheetContext); context.push(AppRoutes.taskNew); }),
        ]),
      ),
    ),
  );
}
