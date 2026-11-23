import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/clock/clock.dart';
import '../../../core/di/data_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/async_body.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/summary_widgets.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/booking.dart';
import '../../../domain/models/catalogue.dart';
import '../../../domain/repositories/booking_repositories.dart';
import '../../../domain/services/availability_service.dart';
import '../../../domain/services/pricing_service.dart';
import '../../cart/cart_notifier.dart';
import 'booking_providers.dart';
import 'common.dart';

/// Pick a date, start time and duration for one space and add it to the cart.
/// Availability shown here is advisory; the server re-checks at checkout.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key, required this.spaceId});
  final String spaceId;

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _dayOffset = 0;
  DateTime? _start;
  int? _minutes;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final space = ref.watch(spaceProvider(widget.spaceId));
    final busy = ref.watch(spaceBusyProvider(widget.spaceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Choose date & time')),
      body: AsyncBody<StudioSpace>(
        value: space,
        onRetry: () => ref.invalidate(spaceProvider(widget.spaceId)),
        data: (s) => AsyncBody<List<BusyInterval>>(
          value: busy,
          onRetry: () => ref.invalidate(spaceBusyProvider(widget.spaceId)),
          data: (b) => _body(context, s, b),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, StudioSpace space, List<BusyInterval> busy) {
    final now = ref.read(clockProvider).now();
    final today = studioDayStart(now);
    final day = today.add(Duration(days: _dayOffset));
    final slots = AvailabilityService.startSlots(
      space: space,
      dayStart: day,
      busy: busy,
      now: now,
      selectedStart: _start,
    ).where((s) => s.state != SlotState.past).toList();
    final text = Theme.of(context).textTheme;

    final start = _start;
    var maxMinutes = 0;
    if (start != null) {
      maxMinutes = AvailabilityService.maxDurationFrom(space: space, start: start, busy: busy);
    }
    final upper = maxMinutes < space.minMinutes ? space.minMinutes : maxMinutes;
    var minutes = _minutes ?? space.minMinutes;
    if (minutes < space.minMinutes) minutes = space.minMinutes;
    if (minutes > upper) minutes = upper;
    final schedule = start == null
        ? null
        : BookingSchedule(start: start, end: start.add(Duration(minutes: minutes)));
    Money? estimate;
    if (schedule != null) {
      final gross = PricingService.lineGross(space.hourlyRate, minutes);
      estimate = gross - gross.percent(space.discountBp);
    }

    return Column(
      children: [
        Expanded(
          child: CenteredBody(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                Text(space.name, style: text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${space.hours.label} · ${fmtDuration(space.minMinutes)} min – ${fmtDuration(space.maxMinutes)} max · ${space.bufferMinutes} min buffer between sessions',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Date', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 30,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final d = today.add(Duration(days: i));
                      final local = toStudioLocal(d);
                      final open = space.hours.isOpenOn(local.weekday);
                      return _DayChip(
                        local: local,
                        selected: i == _dayOffset,
                        closed: !open,
                        onTap: () => setState(() {
                          _dayOffset = i;
                          _start = null;
                          _minutes = null;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Start time', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                if (slots.isEmpty)
                  const Notice(text: 'The space is closed or has no start times left on this day.')
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final s in slots)
                        _SlotButton(
                          info: s,
                          onTap: s.selectable
                              ? () => setState(() {
                                    _start = s.start;
                                    _minutes = null;
                                  })
                              : null,
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Held = another customer is paying or awaiting review. Taken = unavailable.',
                  style: text.bodySmall,
                ),
                if (schedule != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Duration', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (maxMinutes < space.minMinutes)
                    Notice(
                      tone: StatusTone.warning,
                      text: 'Not enough free time from this start. Pick an earlier or later slot (minimum ${fmtDuration(space.minMinutes)}).',
                    )
                  else
                    SectionCard(
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Shorter',
                            onPressed: minutes - AvailabilityService.stepMinutes >= space.minMinutes
                                ? () => setState(() => _minutes = minutes - AvailabilityService.stepMinutes)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(fmtDuration(minutes), style: text.titleLarge),
                                Text('Ends ${fmtTime(schedule.end)}', style: text.bodySmall),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Longer',
                            onPressed: minutes + AvailabilityService.stepMinutes <= maxMinutes
                                ? () => setState(() => _minutes = minutes + AvailabilityService.stepMinutes)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Notes for the studio (optional)',
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 300,
                  ),
                ],
              ],
            ),
          ),
        ),
        StickyBar(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(estimate == null ? 'Select a start time' : 'Estimated', style: text.bodySmall),
                    if (estimate != null) Text(estimate.format(), style: text.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Add to cart',
                  icon: Icons.add_shopping_cart,
                  onPressed: schedule == null || maxMinutes < space.minMinutes
                      ? null
                      : () => _add(space, schedule),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _add(StudioSpace space, BookingSchedule schedule) {
    final cart = ref.read(cartProvider.notifier);
    final error = cart.add(
      CartLine(
        id: cart.newLineId(),
        spaceId: space.id,
        schedule: schedule,
        notes: _notes.text.trim(),
      ),
      space,
    );
    if (error != null) {
      showAppSnack(context, error, error: true);
      return;
    }
    showAppSnack(context, 'Added to your cart. Nothing is reserved until you check out.');
    context.go('/c/cart');
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.local, required this.selected, required this.closed, required this.onTap});
  final DateTime local;
  final bool selected;
  final bool closed;
  final VoidCallback onTap;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = selected ? Colors.white : (closed ? AppColors.mutedText : AppColors.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: '${_days[local.weekday - 1]} ${local.day}${closed ? ', closed' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Container(
          width: 60,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_days[local.weekday - 1], style: text.labelMedium?.copyWith(color: fg)),
              Text('${local.day}', style: text.titleLarge?.copyWith(color: fg)),
              Text(closed ? 'Closed' : ' ', style: text.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.info, required this.onTap});
  final SlotInfo info;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final state = info.state;
    final selected = state == SlotState.selected;
    final enabled = info.selectable;
    final caption = switch (state) {
      SlotState.pending => 'Held',
      SlotState.confirmed || SlotState.unavailable => 'Taken',
      _ => null,
    };
    final fg = selected ? Colors.white : (enabled ? AppColors.ink : AppColors.mutedText);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '${fmtTime(info.start)}${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.field),
        child: Container(
          constraints: const BoxConstraints(minWidth: 92, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : (enabled ? AppColors.card : AppColors.line.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtTime(info.start),
                style: text.labelLarge?.copyWith(
                  color: fg,
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
              if (caption != null) Text(caption, style: text.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
