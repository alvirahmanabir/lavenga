import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/clock/clock.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/booking_repositories.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Manager dashboard. Everything shown is limited to the manager's studios
/// by the repository; the screen never filters data itself.
class ManagerDashboardScreen extends ConsumerStatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  ConsumerState<ManagerDashboardScreen> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends ConsumerState<ManagerDashboardScreen> {
  int _days = 30;
  static const _ranges = {7: 'Last 7 days', 30: 'Last 30 days', 90: 'Last 90 days', 0: 'All time'};

  void _openBookings(BookingFilter filter) {
    final p = ref.read(rolePrefixProvider);
    ref.read(staffBookingFilterProvider.notifier).set(filter);
    context.go('$p/bookings');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final p = ref.watch(rolePrefixProvider);
    final stats = ref.watch(staffDashboardProvider(_days));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('$p/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(staffDashboardProvider(_days)),
        child: AsyncBody<DashboardStats>(
          value: stats,
          onRetry: () => ref.invalidate(staffDashboardProvider(_days)),
          data: (s) => ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter, AppSpacing.lg, AppSpacing.gutter, 0),
                child: Text('Hello, ${user.fullName.split(' ').first}', style: text.headlineMedium),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                  children: [
                    for (final e in _ranges.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Center(
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _days == e.key,
                            onSelected: (_) => setState(() => _days = e.key),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SectionHeader('Needs attention'),
              KpiGrid(children: [
                KpiTile(
                  label: 'Pending confirmations',
                  value: '${s.pendingConfirmations}',
                  icon: Icons.hourglass_top,
                  color: s.pendingConfirmations > 0 ? AppColors.warning : null,
                  onTap: () => _openBookings(
                      const BookingFilter(statuses: {BookingStatus.pendingReview})),
                ),
                KpiTile(
                  label: 'Pending refunds',
                  value: '${s.pendingRefunds}',
                  icon: Icons.currency_exchange,
                  color: s.pendingRefunds > 0 ? AppColors.warning : null,
                  onTap: PermissionPolicy.can(user, StaffPermission.handleRefunds)
                      ? () => context.push('$p/refunds')
                      : null,
                ),
                KpiTile(
                  label: 'Open tickets',
                  value: '${s.openTickets}',
                  icon: Icons.support_agent,
                  onTap: PermissionPolicy.can(user, StaffPermission.handleSupport)
                      ? () => context.push('$p/support')
                      : null,
                ),
                KpiTile(
                  label: 'Escalated tickets',
                  value: '${s.escalatedTickets}',
                  icon: Icons.priority_high,
                  color: s.escalatedTickets > 0 ? AppColors.error : null,
                ),
              ]),
              const SectionHeader('Bookings'),
              KpiGrid(children: [
                KpiTile(
                  label: 'Today',
                  value: '${s.todayBookings}',
                  icon: Icons.today,
                  onTap: () => _openBookings(BookingFilter(
                    from: studioDayStart(ref.read(clockProvider).now()),
                    to: studioDayStart(ref.read(clockProvider).now()).add(const Duration(days: 1)),
                  )),
                ),
                KpiTile(label: 'Upcoming', value: '${s.upcomingBookings}', icon: Icons.event),
                KpiTile(label: 'Active now', value: '${s.activeBookings}', icon: Icons.play_circle_outline),
                KpiTile(label: 'Completed', value: '${s.completedBookings}', icon: Icons.check_circle_outline),
                KpiTile(label: 'Cancelled', value: '${s.cancelledBookings}', icon: Icons.cancel_outlined),
                KpiTile(label: 'All bookings', value: '${s.totalBookings}', icon: Icons.event_note),
              ]),
              if (PermissionPolicy.can(user, StaffPermission.viewPayments)) ...[
                const SectionHeader('Money'),
                KpiGrid(children: [
                  KpiTile(label: 'Booking value', value: s.bookingValue.format(), sub: 'Not yet collected'),
                  KpiTile(
                    label: 'Collected (verified)',
                    value: s.collected.format(),
                    color: AppColors.success,
                  ),
                  KpiTile(
                    label: 'Outstanding dues',
                    value: s.outstanding.format(),
                    color: AppColors.terracotta,
                  ),
                  KpiTile(label: 'Refunded', value: s.refunded.format()),
                ]),
              ],
              const SectionHeader('Booking value by day'),
              SectionCard(child: MiniBarChart(days: s.daily)),
              if (s.topSpaces.isNotEmpty) ...[
                const SectionHeader('Top spaces'),
                SectionCard(
                  child: Column(children: [
                    for (final r in s.topSpaces.take(5))
                      SummaryRow(r.label, r.amount.format(), sub: '${r.count} bookings'),
                  ]),
                ),
              ],
              if (s.topCustomers.isNotEmpty &&
                  PermissionPolicy.can(user, StaffPermission.viewCustomers)) ...[
                const SectionHeader('Top customers'),
                SectionCard(
                  child: Column(children: [
                    for (final r in s.topCustomers.take(5))
                      SummaryRow(r.label, r.amount.format(), sub: '${r.count} bookings'),
                  ]),
                ),
              ],
              if (PermissionPolicy.can(user, StaffPermission.viewReports))
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('$p/reports'),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Open reports'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
