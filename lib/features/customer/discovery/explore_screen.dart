import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/data_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../domain/enums.dart';
import '../../../domain/repositories/catalogue_repositories.dart';
import 'discovery_providers.dart';
import 'discovery_widgets.dart';

String sortLabel(SpaceSort s) => switch (s) {
      SpaceSort.recommended => 'Recommended',
      SpaceSort.priceLow => 'Price: low to high',
      SpaceSort.priceHigh => 'Price: high to low',
      SpaceSort.rating => 'Top rated',
      SpaceSort.popularity => 'Most popular',
      SpaceSort.newest => 'Newest',
    };

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    super.key,
    this.initialCategoryId,
    this.initialQuery,
    this.focusSearch = false,
  });

  final String? initialCategoryId;
  final String? initialQuery;
  final bool focusSearch;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategoryId;
    final q = widget.initialQuery;
    if (cat != null || (q != null && q.isNotEmpty)) {
      // Provider writes must not happen during build.
      Future.microtask(() {
        if (!mounted) return;
        final notifier = ref.read(exploreQueryProvider.notifier);
        final base = ref.read(exploreQueryProvider).cleared();
        notifier.set(cat != null
            ? base.copyWith(categoryId: cat, text: q ?? '')
            : base.copyWith(text: q));
      });
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(exploreQueryProvider);
    final result = await showAppSheet<SpaceQuery>(
      context,
      builder: (_) => FilterSheet(initial: current),
    );
    if (result != null) ref.read(exploreQueryProvider.notifier).set(result);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(exploreQueryProvider);
    final results = ref.watch(exploreResultsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final text = Theme.of(context).textTheme;
    final notifier = ref.read(exploreQueryProvider.notifier);
    final filters = query.activeFilterCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    initialValue: query.text,
                    autofocus: widget.focusSearch,
                    onChanged: (v) => notifier.set(ref.read(exploreQueryProvider).copyWith(text: v)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  tooltip: filters > 0 ? 'Filters, $filters active' : 'Filters',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(AppBreakpoints.minTouchTarget, AppBreakpoints.minTouchTarget),
                  ),
                  icon: Badge(
                    isLabelVisible: filters > 0,
                    label: Text('$filters'),
                    child: const Icon(Icons.tune),
                  ),
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              children: [
                OptionChip(
                  label: 'All',
                  selected: query.categoryId == null,
                  onTap: () => notifier.set(query.copyWith(clearCategory: true)),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: AppSpacing.sm),
                  OptionChip(
                    label: c.name,
                    selected: query.categoryId == c.id,
                    onTap: () => notifier.set(query.copyWith(categoryId: c.id)),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    results.hasValue ? '${results.requireValue.length} spaces' : 'Searching…',
                    style: text.bodySmall,
                  ),
                ),
                if (filters > 0)
                  TextButton(
                    onPressed: () => notifier.set(query.cleared()),
                    child: const Text('Clear filters'),
                  ),
                PopupMenuButton<SpaceSort>(
                  tooltip: 'Sort',
                  initialValue: query.sort,
                  onSelected: (s) => notifier.set(query.copyWith(sort: s)),
                  itemBuilder: (_) => [
                    for (final s in SpaceSort.values)
                      PopupMenuItem(value: s, child: Text(sortLabel(s))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_vert, size: 18),
                        const SizedBox(width: 4),
                        Text(sortLabel(query.sort), style: text.labelLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncBody(
              value: results,
              onRetry: () => ref.invalidate(exploreResultsProvider),
              data: (spaces) {
                if (spaces.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No spaces found',
                    message: 'Try a different search or remove some filters.',
                    actionLabel: 'Clear filters',
                    onAction: () => notifier.set(const SpaceQuery()),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                  child: SpaceGrid(spaces: spaces),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet that edits a draft query and returns it on Apply.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.initial});
  final SpaceQuery initial;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late SpaceQuery q = widget.initial;
  late final _min = TextEditingController(text: _taka(widget.initial.minPrice));
  late final _max = TextEditingController(text: _taka(widget.initial.maxPrice));

  static String _taka(Money? m) => m == null ? '' : '${m.minor ~/ 100}';

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Money? _parse(String v) {
    final n = int.tryParse(v.trim());
    return n == null || n < 0 ? null : Money.taka(n);
  }

  Future<void> _pickDate() async {
    final now = toStudioLocal(ref.read(clockProvider).now());
    final picked = await showDatePicker(
      context: context,
      initialDate: q.date == null ? now : toStudioLocal(q.date!),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => q = q.copyWith(
            date: fromStudioLocal(picked.year, picked.month, picked.day),
          ));
    }
  }

  void _apply() {
    final lo = _parse(_min.text);
    final hi = _parse(_max.text);
    if (lo != null && hi != null && lo > hi) {
      showAppSnack(context, 'Minimum price cannot exceed maximum price', error: true);
      return;
    }
    var result = q;
    if (lo == null && hi == null) {
      result = result.copyWith(clearPrice: true);
    } else {
      // copyWith cannot null one side only; rebuild explicitly.
      result = SpaceQuery(
        text: q.text,
        categoryId: q.categoryId,
        studioId: q.studioId,
        studioIds: q.studioIds,
        minPrice: lo,
        maxPrice: hi,
        date: q.date,
        startMinute: q.startMinute,
        minRating: q.minRating,
        minCapacity: q.minCapacity,
        facilities: q.facilities,
        equipment: q.equipment,
        discountOnly: q.discountOnly,
        sort: q.sort,
        includeInactive: q.includeInactive,
      );
    }
    Navigator.of(context).pop(result);
  }

  Set<String> _toggle(Set<String> s, String v) =>
      s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final opts = ref.watch(filterOptionsProvider).value ?? const FilterOptions();

    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
          child: Text(t, style: text.titleMedium),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              children: [
                Text('Filters', style: text.headlineSmall),
                title('Category'),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                  for (final c in cats)
                    OptionChip(
                      label: c.name,
                      selected: q.categoryId == c.id,
                      onTap: () => setState(() => q = q.categoryId == c.id
                          ? q.copyWith(clearCategory: true)
                          : q.copyWith(categoryId: c.id)),
                    ),
                ]),
                title('Price per hour (৳)'),
                Row(children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Minimum',
                      controller: _min,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Maximum',
                      controller: _max,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                title('Available on'),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(q.date == null ? 'Pick a date' : fmtDateLong(q.date!)),
                    onPressed: _pickDate,
                  ),
                  if (q.date != null) ...[
                    DropdownButton<int?>(
                      value: q.startMinute,
                      hint: const Text('Any start time'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Any start time')),
                        for (var h = 6; h <= 22; h++)
                          DropdownMenuItem<int?>(value: h * 60, child: Text(fmtMinuteOfDay(h * 60))),
                      ],
                      onChanged: (v) => setState(() => q = SpaceQuery(
                            text: q.text,
                            categoryId: q.categoryId,
                            studioId: q.studioId,
                            studioIds: q.studioIds,
                            minPrice: q.minPrice,
                            maxPrice: q.maxPrice,
                            date: q.date,
                            startMinute: v,
                            minRating: q.minRating,
                            minCapacity: q.minCapacity,
                            facilities: q.facilities,
                            equipment: q.equipment,
                            discountOnly: q.discountOnly,
                            sort: q.sort,
                            includeInactive: q.includeInactive,
                          )),
                    ),
                    TextButton(
                      onPressed: () => setState(() => q = q.copyWith(clearDate: true)),
                      child: const Text('Clear date'),
                    ),
                  ],
                ]),
                title('Minimum rating'),
                Wrap(spacing: AppSpacing.sm, children: [
                  for (final r in const [0.0, 3.0, 4.0, 4.5])
                    OptionChip(
                      label: r == 0 ? 'Any' : '$r+',
                      selected: q.minRating == r,
                      onTap: () => setState(() => q = q.copyWith(minRating: r)),
                    ),
                ]),
                title('Minimum capacity'),
                Wrap(spacing: AppSpacing.sm, children: [
                  OptionChip(
                    label: 'Any',
                    selected: q.minCapacity == null,
                    onTap: () => setState(() => q = q.copyWith(clearCapacity: true)),
                  ),
                  for (final c in const [5, 10, 20, 50])
                    OptionChip(
                      label: '$c+',
                      selected: q.minCapacity == c,
                      onTap: () => setState(() => q = q.copyWith(minCapacity: c)),
                    ),
                ]),
                if (opts.facilities.isNotEmpty) ...[
                  title('Facilities'),
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    for (final f in opts.facilities)
                      OptionChip(
                        label: f,
                        selected: q.facilities.contains(f),
                        onTap: () => setState(() => q = q.copyWith(facilities: _toggle(q.facilities, f))),
                      ),
                  ]),
                ],
                if (opts.equipment.isNotEmpty) ...[
                  title('Equipment'),
                  Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                    for (final e in opts.equipment)
                      OptionChip(
                        label: e,
                        selected: q.equipment.contains(e),
                        onTap: () => setState(() => q = q.copyWith(equipment: _toggle(q.equipment, e))),
                      ),
                  ]),
                ],
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Discounted spaces only'),
                  value: q.discountOnly,
                  onChanged: (v) => setState(() => q = q.copyWith(discountOnly: v)),
                ),
                title('Sort by'),
                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                  for (final s in SpaceSort.values)
                    OptionChip(
                      label: sortLabel(s),
                      selected: q.sort == s,
                      onTap: () => setState(() => q = q.copyWith(sort: s)),
                    ),
                ]),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(children: [
                Expanded(
                  child: AppButton(
                    label: 'Reset',
                    kind: AppButtonKind.secondary,
                    onPressed: () => Navigator.of(context).pop(widget.initial.cleared()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 2, child: AppButton(label: 'Show results', onPressed: _apply)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
