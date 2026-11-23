import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/clock/clock.dart';
import '../../core/di/data_providers.dart';
import '../../core/di/providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/models/promo_social.dart';
import 'admin_common.dart';
import 'promotions_screen.dart';

/// Create ('new') or edit a discount, with an optional coupon code.
class DiscountFormScreen extends ConsumerStatefulWidget {
  const DiscountFormScreen({super.key, required this.discountId});
  final String discountId;

  @override
  ConsumerState<DiscountFormScreen> createState() => _DiscountFormScreenState();
}

class _DiscountFormScreenState extends ConsumerState<DiscountFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _minBooking = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _code = TextEditingController();
  final _usageLimit = TextEditingController();
  final _perCustomer = TextEditingController(text: '1');

  DiscountKind _kind = DiscountKind.percentage;
  DiscountScope _scope = DiscountScope.global;
  final Set<String> _targets = {};
  late DateTime _start;
  late DateTime _end;
  bool _active = true;
  bool _loaded = false;
  bool _saving = false;
  Coupon? _coupon;

  bool get _isNew => widget.discountId == 'new';

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _start = studioDayStart(now);
    _end = _start.add(const Duration(days: 30, hours: 23, minutes: 59));
  }

  @override
  void dispose() {
    for (final c in [_name, _value, _minBooking, _maxDiscount, _code, _usageLimit, _perCustomer]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Discount d, List<Coupon> coupons) {
    if (_loaded) return;
    _loaded = true;
    _name.text = d.name;
    _kind = d.kind;
    _value.text = d.kind == DiscountKind.percentage
        ? percentText(d.value)
        : Money.fromMinor(d.value).format().replaceAll(RegExp(r'[^0-9.]'), '');
    _scope = d.scope;
    _targets
      ..clear()
      ..addAll(d.targetIds);
    _start = d.startsAt;
    _end = d.endsAt;
    _active = d.active;
    if (d.minBooking.isPositive) {
      _minBooking.text = d.minBooking.format().replaceAll(RegExp(r'[^0-9.]'), '');
    }
    if (d.maxDiscount != null) {
      _maxDiscount.text = d.maxDiscount!.format().replaceAll(RegExp(r'[^0-9.]'), '');
    }
    final mine = coupons.where((c) => c.discountId == d.id).toList();
    if (mine.isNotEmpty) {
      _coupon = mine.first;
      _code.text = _coupon!.code;
      _usageLimit.text = _coupon!.usageLimit?.toString() ?? '';
      _perCustomer.text = _coupon!.perCustomerLimit.toString();
    }
  }

  Future<void> _pickDate(bool start) async {
    final local = toStudioLocal(start ? _start : _end);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(local.year, local.month, local.day),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = fromStudioLocal(picked.year, picked.month, picked.day, 0);
      } else {
        _end = fromStudioLocal(picked.year, picked.month, picked.day, 23 * 60 + 59);
      }
    });
  }

  Future<void> _save(Discount? existing) async {
    if (!_form.currentState!.validate()) return;
    if (_scope != DiscountScope.global && _targets.isEmpty) {
      showAppSnack(context, 'Choose at least one target for this scope', error: true);
      return;
    }
    final int value;
    if (_kind == DiscountKind.percentage) {
      value = parsePercentBp(_value.text)!;
    } else {
      value = parseMoney(_value.text)!.minor;
    }
    final actor = ref.read(currentUserProvider);
    final repo = ref.read(discountRepositoryProvider);
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      () async {
        final draft = Discount(
          id: existing?.id ?? 'new',
          name: _name.text.trim(),
          kind: _kind,
          value: value,
          scope: _scope,
          targetIds: _scope == DiscountScope.global ? const [] : _targets.toList(),
          minBooking: parseMoney(_minBooking.text) ?? Money.zero,
          maxDiscount: parseMoney(_maxDiscount.text),
          startsAt: _start,
          endsAt: _end,
          active: _active,
        );
        final saved = await repo.saveDiscount(draft, actor: actor);
        final code = _code.text.trim();
        if (code.isNotEmpty) {
          final limit = int.tryParse(_usageLimit.text.trim());
          await repo.saveCoupon(
            Coupon(
              id: _coupon?.id ?? 'new',
              code: code,
              discountId: saved.id,
              usageLimit: limit,
              perCustomerLimit: int.tryParse(_perCustomer.text.trim()) ?? 1,
              redemptions: _coupon?.redemptions ?? const {},
              active: _active,
            ),
            actor: actor,
          );
        }
      },
      success: _isNew ? 'Discount created' : 'Discount saved',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    Discount? existing;
    if (!_isNew) {
      final discounts = ref.watch(discountsProvider);
      final coupons = ref.watch(couponsProvider);
      if (!discounts.hasValue || !coupons.hasValue) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit discount')),
          body: discounts.hasError
              ? Center(child: Text(toFailure(discounts.error!).userMessage))
              : const Center(child: CircularProgressIndicator()),
        );
      }
      final found = discounts.requireValue.where((d) => d.id == widget.discountId);
      if (found.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Edit discount')),
          body: const Center(child: Text('Discount not found')),
        );
      }
      existing = found.first;
      _load(existing, coupons.requireValue);
    }
    final pct = _kind == DiscountKind.percentage;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New discount' : 'Edit discount')),
      body: AdminBody(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              AppTextField(
                label: 'Name',
                controller: _name,
                validator: (v) => requiredField(v, 'Name'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<DiscountKind>(
                segments: const [
                  ButtonSegment(value: DiscountKind.percentage, label: Text('Percentage')),
                  ButtonSegment(value: DiscountKind.fixed, label: Text('Fixed amount')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: pct ? 'Percent off' : 'Amount off (৳)',
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                validator: (v) {
                  if (pct) {
                    final bp = parsePercentBp(v);
                    if (bp == null || bp <= 0 || bp > 10000) return 'Enter 0.01 to 100';
                  } else {
                    final m = parseMoney(v);
                    if (m == null || !m.isPositive) return 'Enter an amount above zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Minimum booking (৳)',
                      controller: _minBooking,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty || parseMoney(v) != null) ? null : 'Invalid',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Cap (৳)',
                      controller: _maxDiscount,
                      helper: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty || parseMoney(v) != null) ? null : 'Invalid',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Applies to', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<DiscountScope>(
                initialValue: _scope,
                items: [
                  for (final s in DiscountScope.values)
                    DropdownMenuItem(value: s, child: Text(discountScopeLabel(s))),
                ],
                onChanged: (v) => setState(() {
                  _scope = v ?? DiscountScope.global;
                  _targets.clear();
                }),
              ),
              if (_scope != DiscountScope.global) ...[
                const SizedBox(height: AppSpacing.md),
                _TargetPicker(
                  scope: _scope,
                  selected: _targets,
                  onChanged: () => setState(() {}),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.event),
                      label: Text('From ${fmtDate(_start)}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event_available),
                      label: Text('To ${fmtDate(_end)}'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Paused discounts are never applied.'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SectionHeader('Coupon code (optional)'),
              AppTextField(
                label: 'Code',
                controller: _code,
                helper: 'Customers type this at checkout. Stored in capitals.',
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]'))],
                validator: (v) =>
                    (v == null || v.trim().isEmpty || v.trim().length >= 3) ? null : 'At least 3 characters',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Total uses',
                      controller: _usageLimit,
                      helper: 'Blank = unlimited',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Per customer',
                      controller: _perCustomer,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              if (_coupon != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text('Used ${_coupon!.usedCount} times so far.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isNew ? 'Create discount' : 'Save changes',
                loading: _saving,
                onPressed: () => _save(existing),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Existing bookings keep the price they were quoted.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetPicker extends ConsumerWidget {
  const _TargetPicker({required this.scope, required this.selected, required this.onChanged});
  final DiscountScope scope;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = <(String, String)>[];
    switch (scope) {
      case DiscountScope.space:
        for (final s in ref.watch(allSpacesProvider).valueOrNull ?? const []) {
          options.add((s.id, '${s.code} · ${s.name}'));
        }
      case DiscountScope.category:
        for (final c in ref.watch(allCategoriesProvider).valueOrNull ?? const []) {
          options.add((c.id, c.name));
        }
      case DiscountScope.customer:
        for (final u in ref.watch(usersProvider((UserRole.customer, ''))).valueOrNull ?? const []) {
          options.add((u.id, u.fullName));
        }
      case DiscountScope.global:
        break;
    }
    if (options.isEmpty) return const Text('Loading choices…');
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(o.$2),
            selected: selected.contains(o.$1),
            onSelected: (v) {
              v ? selected.add(o.$1) : selected.remove(o.$1);
              onChanged();
            },
          ),
      ],
    );
  }
}
