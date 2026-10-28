import 'package:flutter/material.dart';

import '../../core/icons/habit_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../shared/widgets/widgets.dart';

/// Searchable icon sheet. Resolves to the chosen icon key, or null if the
/// sheet is dismissed.
Future<String?> showIconPicker(
  BuildContext context, {
  required String selectedKey,
}) {
  return showTickSheet<String>(
    context: context,
    title: 'Icon',
    builder: (BuildContext sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.7,
      child: _IconPickerBody(selectedKey: selectedKey),
    ),
  );
}

class _IconPickerBody extends StatefulWidget {
  const _IconPickerBody({required this.selectedKey});

  final String selectedKey;

  @override
  State<_IconPickerBody> createState() => _IconPickerBodyState();
}

class _IconPickerBodyState extends State<_IconPickerBody> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final List<HabitIconDef> icons = searchIcons(_query, group: _group);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: TextField(
            onChanged: (String v) => setState(() => _query = v),
            cursorColor: AppColors.cyan,
            decoration: InputDecoration(
              hintText: 'Search icons',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.gapSm),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TickChip(
                  label: 'All',
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
              ),
              for (final String g in kIconGroups)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TickChip(
                    label: g,
                    selected: _group == g,
                    onTap: () => setState(() => _group = g),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: icons.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No icons found',
                  message: 'Try a different word.',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: icons.length,
                  itemBuilder: (BuildContext context, int i) {
                    final HabitIconDef d = icons[i];
                    final bool selected = d.key == widget.selectedKey;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: d.label,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(d.key),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  selected ? AppColors.cyan : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(d.icon, color: Colors.white, size: 26),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
