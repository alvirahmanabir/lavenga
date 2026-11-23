import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../core/utils/time_format.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../../domain/services/payment_calculator.dart';
import '../../domain/services/policies.dart';
import 'mock_context.dart';

/// Shared dashboard and report maths. Manager and administrator views use the
/// same engine; the only difference is the scope filter and which extra
/// platform-wide figures are filled in.
abstract class _StatsBase extends MockRepo {
  _StatsBase(super.ctx);

  bool _inScope(AppUser user, Booking b) => PermissionPolicy.canSeeBooking(user, b);

  Money _bookingValue(Booking b) => switch (b.status) {
        BookingStatus.cancelled ||
        BookingStatus.rejected ||
        BookingStatus.expired =>
          Money.zero,
        _ => b.total,
      };

  DashboardStats buildDashboard(AppUser user, {DateTime? from, DateTime? to}) {
    sweepHolds();
    final isAdmin = user.isAdmin;
    final bookings = db.bookings.where((b) {
      if (!_inScope(user, b)) return false;
      if (from != null && b.createdAt.isBefore(from)) return false;
      if (to != null && b.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
    final ids = {for (final b in bookings) b.id};
    final today = studioDayStart(now);
    final tomorrow = today.add(const Duration(days: 1));

    var value = Money.zero;
    var outstanding = Money.zero;
    var collected = Money.zero;
    var refunded = Money.zero;
    for (final b in bookings) {
      value += _bookingValue(b);
      final pays = paymentsOf(b.id);
      collected += PaymentCalculator.verifiedPaid(pays);
      refunded += refundedOf(b.id);
      if (!b.status.isClosed || b.status == BookingStatus.completed) {
        outstanding += PaymentCalculator.remainingDue(b.total, pays);
      }
    }

    final refunds = db.refunds.where((r) => ids.contains(r.bookingId)).toList();
    final pendingRefunds = refunds
        .where((r) => isAdmin
            ? (r.status == RefundStatus.forwardedToAdmin || r.status == RefundStatus.approved)
            : (r.status == RefundStatus.requested || r.status == RefundStatus.underManagerReview))
        .length;
    final tickets = db.tickets.where((t) {
      if (isAdmin || t.bookingId == null) return true;
      return ids.contains(t.bookingId);
    }).toList();

    // Last 14 days, newest last.
    final daily = <DayValue>[];
    for (var i = 13; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      var amount = Money.zero;
      for (final p in db.payments) {
        if (!ids.contains(p.bookingId) || !p.isVerified) continue;
        final at = p.latest!.at;
        if (!at.isBefore(day) && at.isBefore(next)) amount += p.amount;
      }
      final count = bookings.where((b) => !b.createdAt.isBefore(day) && b.createdAt.isBefore(next)).length;
      daily.add(DayValue(day, amount, count));
    }

    // Top spaces by net line revenue on live bookings.
    final spaceTotals = <String, (Money, int)>{};
    for (final b in bookings) {
      if (b.status == BookingStatus.cancelled ||
          b.status == BookingStatus.rejected ||
          b.status == BookingStatus.expired) {
        continue;
      }
      for (final item in b.items) {
        final line = b.pricing.lines.firstWhere(
          (l) => l.itemId == item.id,
          orElse: () => PricingLine(itemId: item.id, label: item.spaceName, minutes: 0, gross: Money.zero, spaceDiscount: Money.zero),
        );
        final prev = spaceTotals[item.spaceName] ?? (Money.zero, 0);
        spaceTotals[item.spaceName] = (prev.$1 + line.net, prev.$2 + 1);
      }
    }
    final topSpaces = [
      for (final e in spaceTotals.entries) RankedItem(e.key, e.value.$1, e.value.$2),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    final customerTotals = <String, (Money, int)>{};
    for (final b in bookings) {
      final paid = PaymentCalculator.verifiedPaid(paymentsOf(b.id));
      final prev = customerTotals[b.customerName] ?? (Money.zero, 0);
      customerTotals[b.customerName] = (prev.$1 + paid, prev.$2 + 1);
    }
    final topCustomers = [
      for (final e in customerTotals.entries) RankedItem(e.key, e.value.$1, e.value.$2),
    ]..sort((a, b) => b.amount.compareTo(a.amount));

    final managers = <ManagerStat>[];
    if (isAdmin) {
      for (final m in db.users.where((u) => u.isManager)) {
        var handled = 0;
        var confirmed = 0;
        var cancelled = 0;
        for (final b in db.bookings) {
          for (final e in b.timeline) {
            if (e.actor != m.fullName) continue;
            handled++;
            if (e.title == 'Confirmed') confirmed++;
            if (e.title == 'Cancelled') cancelled++;
          }
        }
        managers.add(ManagerStat(m.fullName, handled, confirmed, cancelled));
      }
    }

    return DashboardStats(
      totalBookings: bookings.length,
      todayBookings: bookings
          .where((b) =>
              b.status.occupiesSlot &&
              b.items.any((i) => !i.schedule.start.isBefore(today) && i.schedule.start.isBefore(tomorrow)))
          .length,
      upcomingBookings: bookings
          .where((b) => b.status.occupiesSlot && b.firstStart.isAfter(now))
          .length,
      pendingConfirmations:
          bookings.where((b) => b.status == BookingStatus.pendingReview && b.holdExpiresAt == null).length,
      activeBookings: bookings
          .where((b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.inProgress)
          .length,
      completedBookings: bookings.where((b) => b.status == BookingStatus.completed).length,
      cancelledBookings: bookings
          .where((b) => b.status == BookingStatus.cancelled || b.status == BookingStatus.rejected)
          .length,
      bookingValue: value,
      collected: collected,
      outstanding: outstanding,
      refunded: refunded,
      pendingRefunds: pendingRefunds,
      openTickets: tickets
          .where((t) => t.status != TicketStatus.resolved && t.status != TicketStatus.closed)
          .length,
      escalatedTickets: tickets.where((t) => t.status == TicketStatus.escalated).length,
      totalCustomers: isAdmin ? db.users.where((u) => u.isCustomer).length : 0,
      totalManagers: isAdmin ? db.users.where((u) => u.isManager).length : 0,
      totalStudios: isAdmin
          ? db.studios.where((s) => !s.archived).length
          : (user.manager?.studioIds.length ?? 0),
      totalSpaces: db.spaces
          .where((s) => s.status != SpaceStatus.archived && PermissionPolicy.managesStudio(user, s.studioId))
          .length,
      daily: daily,
      topSpaces: topSpaces.take(5).toList(),
      topCustomers: topCustomers.take(5).toList(),
      managerPerformance: managers,
    );
  }

  ReportData buildReport(AppUser user, ReportKind kind, {DateTime? from, DateTime? to}) {
    if (user.isManager) requirePermission(user, StaffPermission.viewReports);
    if (user.isCustomer) throw const Forbidden('reports');
    sweepHolds();
    final start = from ?? studioDayStart(now).subtract(const Duration(days: 13));
    final end = to ?? studioDayStart(now).add(const Duration(days: 1));
    final scoped = db.bookings.where((b) => _inScope(user, b)).toList();
    String taka(Money m) => m.format();

    switch (kind) {
      case ReportKind.dailyBookings:
        final rows = <List<String>>[];
        var totalCount = 0;
        var totalValue = Money.zero;
        var totalCollected = Money.zero;
        for (var day = start; day.isBefore(end); day = day.add(const Duration(days: 1))) {
          final next = day.add(const Duration(days: 1));
          final dayBookings =
              scoped.where((b) => !b.createdAt.isBefore(day) && b.createdAt.isBefore(next)).toList();
          final value = dayBookings.fold(Money.zero, (s, b) => s + _bookingValue(b));
          var collected = Money.zero;
          for (final p in db.payments) {
            if (!p.isVerified || !scoped.any((b) => b.id == p.bookingId)) continue;
            final at = p.latest!.at;
            if (!at.isBefore(day) && at.isBefore(next)) collected += p.amount;
          }
          totalCount += dayBookings.length;
          totalValue += value;
          totalCollected += collected;
          rows.add([fmtDate(day), '${dayBookings.length}', taka(value), taka(collected)]);
        }
        return ReportData(
          title: 'Daily bookings',
          headers: const ['Date', 'Bookings', 'Booking value', 'Collected'],
          rows: rows,
          summary: {
            'Bookings': '$totalCount',
            'Booking value': taka(totalValue),
            'Collected': taka(totalCollected),
          },
        );

      case ReportKind.monthlyBookings:
        final local = toStudioLocal(now);
        final rows = <List<String>>[];
        var totalValue = Money.zero;
        for (var i = 5; i >= 0; i--) {
          final monthStartLocal = DateTime.utc(local.year, local.month - i, 1);
          final nextLocal = DateTime.utc(local.year, local.month - i + 1, 1);
          final s = fromStudioLocal(monthStartLocal.year, monthStartLocal.month, 1);
          final e = fromStudioLocal(nextLocal.year, nextLocal.month, 1);
          final list = scoped.where((b) => !b.createdAt.isBefore(s) && b.createdAt.isBefore(e)).toList();
          final value = list.fold(Money.zero, (sum, b) => sum + _bookingValue(b));
          final collected = list.fold(Money.zero, (sum, b) => sum + PaymentCalculator.verifiedPaid(paymentsOf(b.id)));
          final refunded = list.fold(Money.zero, (sum, b) => sum + refundedOf(b.id));
          totalValue += value;
          rows.add([
            fmtDateLong(s).substring(fmtDateLong(s).indexOf(' ') + 1),
            '${list.length}',
            taka(value),
            taka(collected),
            taka(refunded),
          ]);
        }
        return ReportData(
          title: 'Monthly bookings',
          headers: const ['Month', 'Bookings', 'Booking value', 'Collected', 'Refunded'],
          rows: rows,
          summary: {'Booking value (6 months)': taka(totalValue)},
        );

      case ReportKind.collections:
        final rows = <List<String>>[];
        var total = Money.zero;
        final payments = db.payments.where((p) {
          if (!p.isVerified) return false;
          final b = bookingById(p.bookingId);
          if (!_inScope(user, b)) return false;
          final at = p.latest!.at;
          return !at.isBefore(start) && at.isBefore(end);
        }).toList()
          ..sort((a, b) => b.latest!.at.compareTo(a.latest!.at));
        for (final p in payments) {
          total += p.amount;
          rows.add([
            fmtDateLong(p.latest!.at),
            p.bookingRef,
            bookingById(p.bookingId).customerName,
            p.latest!.method.label,
            p.kind.name,
            taka(p.amount),
          ]);
        }
        return ReportData(
          title: 'Collections',
          headers: const ['Date', 'Booking', 'Customer', 'Method', 'Type', 'Amount'],
          rows: rows,
          summary: {'Collected': taka(total), 'Payments': '${rows.length}'},
        );

      case ReportKind.outstanding:
        final rows = <List<String>>[];
        var totalDue = Money.zero;
        for (final b in scoped) {
          if (b.status == BookingStatus.cancelled ||
              b.status == BookingStatus.rejected ||
              b.status == BookingStatus.expired) {
            continue;
          }
          final pays = paymentsOf(b.id);
          final due = PaymentCalculator.remainingDue(b.total, pays);
          if (!due.isPositive) continue;
          totalDue += due;
          rows.add([
            b.reference,
            b.customerName,
            taka(b.total),
            taka(PaymentCalculator.verifiedPaid(pays)),
            taka(due),
            fmtDate(b.firstStart),
          ]);
        }
        return ReportData(
          title: 'Outstanding payments',
          headers: const ['Booking', 'Customer', 'Total', 'Paid', 'Due', 'First session'],
          rows: rows,
          summary: {'Outstanding': taka(totalDue), 'Bookings': '${rows.length}'},
        );

      case ReportKind.spacePerformance:
        final rows = <List<String>>[];
        var totalRevenue = Money.zero;
        for (final s in db.spaces) {
          if (s.status == SpaceStatus.archived || !PermissionPolicy.managesStudio(user, s.studioId)) {
            continue;
          }
          var count = 0;
          var minutes = 0;
          var revenue = Money.zero;
          for (final b in scoped) {
            if (b.status == BookingStatus.cancelled ||
                b.status == BookingStatus.rejected ||
                b.status == BookingStatus.expired) {
              continue;
            }
            for (final item in b.items.where((i) => i.spaceId == s.id)) {
              count++;
              minutes += item.schedule.minutes;
              for (final l in b.pricing.lines.where((l) => l.itemId == item.id)) {
                revenue += l.net;
              }
            }
          }
          totalRevenue += revenue;
          rows.add([
            s.code,
            s.name,
            '$count',
            (minutes / 60).toStringAsFixed(1),
            taka(revenue),
            s.ratingCount == 0 ? '—' : s.ratingAvg.toStringAsFixed(1),
          ]);
        }
        return ReportData(
          title: 'Space performance',
          headers: const ['Code', 'Space', 'Bookings', 'Hours', 'Revenue', 'Rating'],
          rows: rows,
          summary: {'Revenue': taka(totalRevenue)},
        );
    }
  }
}

class MockManagerRepository extends _StatsBase implements ManagerRepository {
  MockManagerRepository(super.ctx);

  @override
  Future<DashboardStats> dashboard(AppUser actor, {DateTime? from, DateTime? to}) async {
    await wait();
    final user = fresh(actor);
    if (!user.isManager && !user.isAdmin) throw const Forbidden('dashboard');
    return buildDashboard(user, from: from, to: to);
  }

  @override
  Future<ReportData> report(AppUser actor, ReportKind kind, {DateTime? from, DateTime? to}) async {
    await wait();
    return buildReport(fresh(actor), kind, from: from, to: to);
  }
}

class MockAdminRepository extends _StatsBase implements AdminRepository {
  MockAdminRepository(super.ctx);

  @override
  Future<DashboardStats> dashboard(AppUser actor, {DateTime? from, DateTime? to}) async {
    await wait();
    requireAdmin(actor);
    return buildDashboard(fresh(actor), from: from, to: to);
  }

  @override
  Future<ReportData> report(AppUser actor, ReportKind kind, {DateTime? from, DateTime? to}) async {
    await wait();
    requireAdmin(actor);
    return buildReport(fresh(actor), kind, from: from, to: to);
  }

  @override
  Future<List<AuditLog>> auditLogs({
    bool sensitiveOnly = false,
    UserRole? role,
    bool loginsOnly = false,
  }) async {
    return db.audit.where((a) {
      if (sensitiveOnly && !a.sensitive) return false;
      if (role != null && a.actorRole != role) return false;
      final isLogin = a.action == 'login';
      if (loginsOnly && !isLogin) return false;
      if (!loginsOnly && isLogin) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
  }

  @override
  Future<PlatformSettings> getSettings() async => db.settings;

  @override
  Future<PlatformSettings> saveSettings(PlatformSettings settings, {required AppUser actor}) async {
    await wait();
    requireAdmin(actor);
    if (settings.advanceBp < 0 || settings.advanceBp > 10000) {
      throw const ValidationFailure('Advance must be between 0% and 100%');
    }
    if (settings.holdMinutes < 1 || settings.holdMinutes > 60) {
      throw const ValidationFailure('Hold time must be 1 to 60 minutes');
    }
    if (settings.vatBp < 0 || settings.vatBp > 3000) {
      throw const ValidationFailure('Tax must be between 0% and 30%');
    }
    db.settings = settings;
    audit(actor, 'Updated platform settings', 'Settings', sensitive: true);
    commit();
    return settings;
  }

  @override
  Future<void> resetDemoData() async {
    db.reset(now);
    ctx.onChange();
  }
}
