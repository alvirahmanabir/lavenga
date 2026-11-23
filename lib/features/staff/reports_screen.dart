import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/session/session.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/async_body.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/summary_widgets.dart';
import '../../domain/enums.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../../domain/services/policies.dart';
import 'staff_providers.dart';
import 'staff_widgets.dart';

/// Five scoped reports. Export is a preview: the CSV is copied to the
/// clipboard; the real backend will generate and sign downloadable files.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsScreen> {
  ReportKind _kind = ReportKind.dailyBookings;
  int _days = 30;

  static const _kinds = {
    ReportKind.dailyBookings: 'Daily bookings',
    ReportKind.monthlyBookings: 'Monthly bookings',
    ReportKind.collections: 'Collections',
    ReportKind.outstanding: 'Outstanding dues',
    ReportKind.spacePerformance: 'Space performance',
  };
  static const _ranges = {7: '7 days', 30: '30 days', 90: '90 days', 0: 'All time'};

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final text = Theme.of(context).textTheme;
    if (!PermissionPolicy.can(user, StaffPermission.viewReports)) {
      return Scaffold(appBar: AppBar(title: const Text('Reports')), body: const NoAccess(what: 'reports'));
    }
    final report = ref.watch(staffReportProvider((_kind, _days)));
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 6),
            children: [
              for (final e in _kinds.entries)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _days,
                decoration: const InputDecoration(labelText: 'Period'),
                items: [
                  for (final e in _ranges.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _days = v ?? _days),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () async {
                final data = await ref.read(staffReportProvider((_kind, _days)).future);
                await Clipboard.setData(ClipboardData(text: data.toCsv()));
                if (context.mounted) {
                  showAppSnack(context, 'CSV copied (preview of the server export)');
                }
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy CSV'),
            ),
          ]),
        ),
        Expanded(
          child: AsyncBody<ReportData>(
            value: report,
            onRetry: () => ref.invalidate(staffReportProvider((_kind, _days))),
            data: (d) => ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                if (d.summary.isNotEmpty)
                  SectionCard(
                    title: d.title,
                    child: Column(children: [
                      for (final e in d.summary.entries) SummaryRow(e.key, e.value),
                    ]),
                  ),
                if (d.rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.gutter),
                    child: Text('No data for this period.'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingTextStyle: text.labelLarge,
                        columns: [for (final h in d.headers) DataColumn(label: Text(h))],
                        rows: [
                          for (final r in d.rows)
                            DataRow(cells: [for (final c in r) DataCell(Text(c))]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
