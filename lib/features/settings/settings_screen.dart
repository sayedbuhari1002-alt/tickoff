import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Settings menu, laid out like the reference. Only entries that exist in the
/// original and are allowed by the spec are listed: there is deliberately no
/// premium entry, no Cloud Backup and no cloud sync.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.pagePadding),
        children: <Widget>[
          _Group(
            children: <Widget>[
              _Tile(
                icon: Icons.ios_share_rounded,
                label: 'Share Progress',
                route: AppRoutes.shareProgress,
              ),
            ],
          ),
          _Group(
            children: <Widget>[
              _Tile(
                icon: Icons.palette_outlined,
                label: 'Theme',
                route: AppRoutes.theme,
              ),
              _Tile(
                icon: Icons.grid_view_rounded,
                label: 'Layout',
                route: AppRoutes.layout,
              ),
              _Tile(
                icon: Icons.widgets_outlined,
                label: 'Widgets',
                route: AppRoutes.widgets,
              ),
            ],
          ),
          _Group(
            children: <Widget>[
              _Tile(
                icon: Icons.settings_outlined,
                label: 'General',
                route: AppRoutes.general,
              ),
              _Tile(
                icon: Icons.reorder_rounded,
                label: 'Rearrange',
                route: AppRoutes.rearrange,
              ),
              _Tile(
                icon: Icons.category_outlined,
                label: 'Categories',
                route: AppRoutes.categories,
              ),
              _Tile(
                icon: Icons.inventory_2_outlined,
                label: 'Archive',
                route: AppRoutes.archive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.gap),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.route});

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
