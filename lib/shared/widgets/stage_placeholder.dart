import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Temporary screen for a route whose real implementation is scheduled for a
/// later stage. Every use is listed in the project checklist and is replaced
/// when its stage is built; none of them is meant to ship.
class StagePlaceholderScreen extends StatelessWidget {
  const StagePlaceholderScreen({
    super.key,
    required this.title,
    required this.stage,
    required this.description,
  });

  final String title;
  final int stage;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: Icons.construction_rounded,
        title: 'Built in Stage $stage',
        message: description,
      ),
    );
  }
}
