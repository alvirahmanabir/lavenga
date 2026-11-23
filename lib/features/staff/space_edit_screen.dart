import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/clock/clock.dart';
import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Create or edit a space. [spaceId] "new" creates one inside [studioId].
/// Price fields are disabled without the pricing permission; the repository
/// enforces the same rule.
class SpaceEditScreen extends ConsumerWidget {
  const SpaceEditScreen({super.key, required this.spaceId, this.studioId});
  final String spaceId;
  final String? studioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (spaceId == 'new') {
      if (studioId == null) {
        return Scaffold(appBar: AppBar(), body: const NoAccess(what: 'this form'));
      }
      return _Form(existing: null, studioId: studioId!);
    }
    final space = ref.watch(spaceProvider(spaceId));
    return AsyncBody<StudioSpace>(
      value: space,
      onRetry: () => ref.invalidate(spaceProvider(spaceId)),
      loading: Scaffold(appBar: AppBar(), body: const ListSkeleton()),
      data: (s) => _Form(existing: s, studioId: s.studioId),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.existing, required this.studioId});
  final StudioSpace? existing;
  final String studioId;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _capacity;
  late final TextEditingController _dims;
  late final TextEditingController _rate;
  late final TextEditingController _discount;
  late final TextEditingController _minMin;
  late final TextEditingController _maxMin;
  late final TextEditingController _buffer;
  late final TextEditingController _facilities;
  late final TextEditingController _equipment;
  late final TextEditingController _rules;
  late final TextEditingController _images;
  String? _categoryId;
  late int _open;
  late int _close;
  late Set<int> _closed;
  late SpaceStatus _status;
  bool _saving = false;
  String _code = '';

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name ?? '');
    _desc = TextEditingController(text: s?.description ?? '');
    _capacity = TextEditingController(text: '${s?.capacity ?? 4}');
    _dims = TextEditingController(text: s?.dimensions ?? '');
    _rate = TextEditingController(
        text: s == null ? '' : (s.hourlyRate.minor / 100).toStringAsFixed(s.hourlyRate.minor % 100 == 0 ? 0 : 2));
    _discount = TextEditingController(text: '${(s?.discountBp ?? 0) / 100}');
    _minMin = TextEditingController(text: '${s?.minMinutes ?? 60}');
    _maxMin = TextEditingController(text: '${s?.maxMinutes ?? 480}');
    _buffer = TextEditingController(text: '${s?.bufferMinutes ?? 30}');
    _facilities = TextEditingController(text: (s?.facilities ?? const []).join(', '));
    _equipment = TextEditingController(text: (s?.equipment ?? const []).join(', '));
    _rules = TextEditingController(text: (s?.rules ?? const []).join('\n'));
    _images = TextEditingController(text: (s?.images ?? const []).join('\n'));
    _categoryId = s?.categoryId;
    _open = s?.hours.openMinute ?? 9 * 60;
    _close = s?.hours.closeMinute ?? 21 * 60;
    _closed = {...(s?.hours.closedWeekdays ?? const <int>[])};
    _status = s?.status ?? SpaceStatus.active;
    _code = s?.code ?? '';
    if (_isNew) {
      ref.read(spaceRepositoryProvider).nextSpaceCode(widget.studioId).then((c) {
        if (mounted) setState(() => _code = c);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _desc, _capacity, _dims, _rate, _discount, _minMin, _maxMin,
      _buffer, _facilities, _equipment, _rules, _images,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _split(String v, Pattern sep) =>
      [for (final p in v.split(sep)) if (p.trim().isNotEmpty) p.trim()];

  Future<void> _pickTime(bool opening) async {
    final current = opening ? _open : _close;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ~/ 60) % 24, minute: current % 60),
    );
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      opening ? _open = m : _close = m;
    });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_categoryId == null) {
      showAppSnack(context, 'Choose a category', error: true);
      return;
    }
    if (_close <= _open) {
      showAppSnack(context, 'Closing time must be after opening time', error: true);
      return;
    }
    final actor = ref.read(currentUserProvider);
    final rate = Money.parse(_rate.text);
    final discountBp = (double.parse(_discount.text.trim().isEmpty ? '0' : _discount.text) * 100).round();
    final hours = OperatingHours(
      openMinute: _open,
      closeMinute: _close,
      closedWeekdays: _closed.toList()..sort(),
    );
    final old = widget.existing;
    final space = old == null
        ? StudioSpace(
            id: 'space_${DateTime.now().microsecondsSinceEpoch}',
            code: _code,
            studioId: widget.studioId,
            name: _name.text.trim(),
            categoryId: _categoryId!,
            description: _desc.text.trim(),
            images: _split(_images.text, '\n'),
            facilities: _split(_facilities.text, ','),
            equipment: _split(_equipment.text, ','),
            rules: _split(_rules.text, '\n'),
            capacity: int.parse(_capacity.text),
            dimensions: _dims.text.trim(),
            hourlyRate: rate,
            discountBp: discountBp,
            hours: hours,
            minMinutes: int.parse(_minMin.text),
            maxMinutes: int.parse(_maxMin.text),
            bufferMinutes: int.parse(_buffer.text),
            status: _status,
            createdAt: ref.read(clockProvider).now(),
          )
        : old.copyWith(
            name: _name.text.trim(),
            categoryId: _categoryId,
            description: _desc.text.trim(),
            images: _split(_images.text, '\n'),
            facilities: _split(_facilities.text, ','),
            equipment: _split(_equipment.text, ','),
            rules: _split(_rules.text, '\n'),
            capacity: int.parse(_capacity.text),
            dimensions: _dims.text.trim(),
            hourlyRate: rate,
            discountBp: discountBp,
            hours: hours,
            minMinutes: int.parse(_minMin.text),
            maxMinutes: int.parse(_maxMin.text),
            bufferMinutes: int.parse(_buffer.text),
            status: _status,
          );
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () async {
        await ref.read(spaceRepositoryProvider).saveSpace(space, actor: actor);
      },
      success: _isNew ? 'Space created' : 'Space saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).maybePop();
  }

  String? _requiredText(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _intField(String? v) => int.tryParse((v ?? '').trim()) == null ? 'Whole number' : null;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cats = ref.watch(categoriesProvider);
    final canEdit = PermissionPolicy.can(
        user, _isNew ? StaffPermission.createSpaces : StaffPermission.manageSpaces);
    final canPrice = PermissionPolicy.can(user, StaffPermission.managePricing);
    const gap = SizedBox(height: AppSpacing.md);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (!canEdit) {
      return Scaffold(appBar: AppBar(), body: const NoAccess(what: 'space editing'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New space' : 'Edit space')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Space code'),
              child: Text(_code.isEmpty ? 'Generating…' : _code),
            ),
            gap,
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: _requiredText,
            ),
            gap,
            cats.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load categories'),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: list.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in list) DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
            ),
            gap,
            TextFormField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: _requiredText,
            ),
            gap,
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  validator: _intField,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _dims,
                  decoration: const InputDecoration(labelText: 'Dimensions'),
                ),
              ),
            ]),
            gap,
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _rate,
                  enabled: canPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Hourly rate (৳)',
                    helperText: canPrice ? null : 'Pricing permission required',
                  ),
                  validator: (v) {
                    try {
                      return Money.parse(v ?? '').isPositive ? null : 'Must be above zero';
                    } on FormatException {
                      return 'Enter an amount';
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _discount,
                  enabled: canPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Space discount %'),
                  validator: (v) {
                    final d = double.tryParse((v ?? '').trim());
                    if (d == null || d < 0 || d > 100) return '0 to 100';
                    return null;
                  },
                ),
              ),
            ]),
            const SectionHeader('Booking rules', padding: EdgeInsets.only(top: AppSpacing.lg)),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _minMin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Min minutes'),
                  validator: _intField,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _maxMin,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Max minutes'),
                  validator: _intField,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _buffer,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Buffer min'),
                  validator: _intField,
                ),
              ),
            ]),
            gap,
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text('Opens ${fmtMinuteOfDay(_open)}'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text('Closes ${fmtMinuteOfDay(_close)}'),
                ),
              ),
            ]),
            gap,
            Text('Closed on', style: Theme.of(context).textTheme.labelLarge),
            Wrap(spacing: AppSpacing.sm, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(days[d - 1]),
                  selected: _closed.contains(d),
                  onSelected: (on) => setState(() => on ? _closed.add(d) : _closed.remove(d)),
                ),
            ]),
            const SectionHeader('Details', padding: EdgeInsets.only(top: AppSpacing.lg)),
            TextFormField(
              controller: _facilities,
              decoration: const InputDecoration(
                  labelText: 'Facilities', helperText: 'Separate with commas'),
            ),
            gap,
            TextFormField(
              controller: _equipment,
              decoration: const InputDecoration(
                  labelText: 'Equipment', helperText: 'Separate with commas'),
            ),
            gap,
            TextFormField(
              controller: _rules,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Rules', helperText: 'One rule per line'),
            ),
            gap,
            TextFormField(
              controller: _images,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Image URLs', helperText: 'One per line (upload arrives with the backend)'),
            ),
            gap,
            DropdownButtonFormField<SpaceStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: SpaceStatus.active, child: Text('Active')),
                DropdownMenuItem(value: SpaceStatus.inactive, child: Text('Inactive (hidden)')),
                DropdownMenuItem(value: SpaceStatus.archived, child: Text('Archived')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isNew ? 'Create space' : 'Save changes'),
            ),
            if (!_isNew) _Blocks(spaceId: widget.existing!.id),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Maintenance and unavailability blocks for one space.
class _Blocks extends ConsumerWidget {
  const _Blocks({required this.spaceId});
  final String spaceId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider).now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (range == null || !context.mounted) return;
    final reason = await askReason(
      context,
      title: 'Block these days',
      hint: 'e.g. Maintenance',
      confirmLabel: 'Block',
      destructive: false,
    );
    if (reason == null || !context.mounted) return;
    final actor = ref.read(currentUserProvider);
    await runGuarded(
      context,
      () => ref.read(spaceRepositoryProvider).addBlock(
            spaceId,
            start: fromStudioLocal(range.start.year, range.start.month, range.start.day),
            end: fromStudioLocal(range.end.year, range.end.month, range.end.day)
                .add(const Duration(days: 1)),
            reason: reason,
            actor: actor,
          ),
      success: 'Dates blocked',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(spaceBlocksProvider(spaceId));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Blocked dates', padding: EdgeInsets.only(top: AppSpacing.xl)),
      blocks.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const Text('Could not load blocks'),
        data: (list) => Column(children: [
          if (list.isEmpty) const ListTile(title: Text('No blocked dates')),
          for (final b in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${fmtDate(b.start)} – ${fmtDate(b.end.subtract(const Duration(minutes: 1)))}'),
              subtitle: Text(b.reason),
              trailing: IconButton(
                tooltip: 'Remove block',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showConfirmDialog(
                    context,
                    title: 'Remove block?',
                    message: 'These dates become bookable again.',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  final actor = ref.read(currentUserProvider);
                  await runGuarded(
                    context,
                    () => ref.read(spaceRepositoryProvider).removeBlock(b.id, actor: actor),
                    success: 'Block removed',
                  );
                },
              ),
            ),
        ]),
      ),
      OutlinedButton.icon(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.block),
        label: const Text('Block dates'),
      ),
    ]);
  }
}
