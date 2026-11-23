import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/repositories/engagement_repositories.dart';
import 'admin_common.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/a/notifications'),
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/a/profile'),
          ),
        ],
      ),
      body: AsyncBody<DashboardStats>(
        value: stats,
        onRetry: () => ref.invalidate(adminStatsProvider),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatsProvider);
            await ref.read(adminStatsProvider.future);
          },
          child: AdminBody(child: _Content(stats: s, name: user?.fullName ?? 'Administrator')),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.stats, required this.name});
  final DashboardStats stats;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text('Welcome, ${name.split(' ').first}', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text('Platform overview across all studios', style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        // Four separate money figures: never blended into one "revenue".
        TileGrid(children: [
          StatTile(
            label: 'Booking value',
            value: s.bookingValue.format(),
            icon: Icons.receipt_long_outlined,
            hint: 'Totals of live bookings',
          ),
          StatTile(
            label: 'Collected',
            value: s.collected.format(),
            icon: Icons.account_balance_wallet_outlined,
            hint: 'Verified payments',
            onTap: () => context.push('/a/payments'),
          ),
          StatTile(
            label: 'Outstanding',
            value: s.outstanding.format(),
            icon: Icons.hourglass_bottom,
            hint: 'Still to collect',
          ),
          StatTile(
            label: 'Refunded',
            value: s.refunded.format(),
            icon: Icons.undo,
            hint: 'Completed refunds',
          ),
        ]),
        const SectionHeader('Needs attention', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
        TileGrid(children: [
          StatTile(
            label: 'Pending confirmations',
            value: '${s.pendingConfirmations}',
            icon: Icons.schedule,
            onTap: () => context.go('/a/orders'),
          ),
          StatTile(
            label: 'Refunds to review',
            value: '${s.pendingRefunds}',
            icon: Icons.assignment_return_outlined,
            onTap: () => context.push('/a/refunds'),
          ),
          StatTile(
            label: 'Open tickets',
            value: '${s.openTickets}',
            icon: Icons.support_agent,
            onTap: () => context.push('/a/support'),
          ),
          StatTile(
            label: 'Escalated tickets',
            value: '${s.escalatedTickets}',
            icon: Icons.priority_high,
            onTap: () => context.push('/a/support'),
          ),
        ]),
        const SectionHeader('Bookings', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
        TileGrid(children: [
          StatTile(label: 'Today', value: '${s.todayBookings}', icon: Icons.today),
          StatTile(label: 'Upcoming', value: '${s.upcomingBookings}', icon: Icons.event_available),
          StatTile(label: 'Active', value: '${s.activeBookings}', icon: Icons.play_circle_outline),
          StatTile(label: 'Completed', value: '${s.completedBookings}', icon: Icons.task_alt),
          StatTile(label: 'Cancelled', value: '${s.cancelledBookings}', icon: Icons.cancel_outlined),
          StatTile(label: 'All time', value: '${s.totalBookings}', icon: Icons.event_note_outlined),
        ]),
        const SectionHeader('Platform', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
        TileGrid(children: [
          StatTile(
            label: 'Studios',
            value: '${s.totalStudios}',
            icon: Icons.store_outlined,
            onTap: () => context.go('/a/catalogue'),
          ),
          StatTile(
            label: 'Spaces',
            value: '${s.totalSpaces}',
            icon: Icons.meeting_room_outlined,
            onTap: () => context.go('/a/catalogue'),
          ),
          StatTile(
            label: 'Customers',
            value: '${s.totalCustomers}',
            icon: Icons.people_outline,
            onTap: () => context.go('/a/people'),
          ),
          StatTile(
            label: 'Managers',
            value: '${s.totalManagers}',
            icon: Icons.badge_outlined,
            onTap: () => context.go('/a/people'),
          ),
        ]),
        if (s.daily.isNotEmpty) ...[
          const SectionHeader('Collected, last days', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
          _DailyBars(values: s.daily),
        ],
        if (s.topSpaces.isNotEmpty) ...[
          const SectionHeader('Top spaces', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
          _RankedList(items: s.topSpaces),
        ],
        if (s.topCustomers.isNotEmpty) ...[
          const SectionHeader('Top customers', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
          _RankedList(items: s.topCustomers),
        ],
        if (s.managerPerformance.isNotEmpty) ...[
          const SectionHeader('Manager activity', padding: EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md)),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  for (final m in s.managerPerformance)
                    SummaryRow(
                      m.name,
                      '${m.handled} handled',
                      sub: '${m.confirmed} confirmed, ${m.cancelled} cancelled',
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ActionChip(
              avatar: const Icon(Icons.bar_chart, size: 18),
              label: const Text('Reports'),
              onPressed: () => context.push('/a/reports'),
            ),
            ActionChip(
              avatar: const Icon(Icons.history, size: 18),
              label: const Text('Audit log'),
              onPressed: () => context.push('/a/audit'),
            ),
            ActionChip(
              avatar: const Icon(Icons.local_offer_outlined, size: 18),
              label: const Text('Promotions'),
              onPressed: () => context.push('/a/promotions'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.values});
  final List<DayValue> values;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxMinor = values.fold<int>(1, (m, v) => v.amount.minor > m ? v.amount.minor : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          label: 'Collected per day. ${values.map((v) => '${fmtDate(v.day)} ${v.amount.format()}').join(', ')}',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final v in values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4 + 80 * (v.amount.minor / maxMinor),
                              decoration: BoxDecoration(
                                color: AppColors.terracotta,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              toStudioLocal(v.day).day.toString(),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.items});
  final List<RankedItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++)
              SummaryRow(
                '${i + 1}. ${items[i].label}',
                items[i].amount.format(),
                sub: '${items[i].count} bookings',
              ),
          ],
        ),
      ),
    );
  }
}
