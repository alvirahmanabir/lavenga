import '../../core/clock/clock.dart';
import '../../core/errors/app_failure.dart';
import '../../core/money/money.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/catalogue.dart';
import '../../domain/models/payment_refund.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/services/availability_service.dart';
import '../../domain/services/payment_calculator.dart';
import '../../domain/services/policies.dart';
import 'mock_database.dart';

/// Everything a mock repository needs: the database, a clock, simulated
/// network latency and a change notifier that refreshes UI providers.
class MockContext {
  MockContext({
    required this.db,
    required this.clock,
    required this.onChange,
    this.latency = const Duration(milliseconds: 80),
  });

  final MockDatabase db;
  final Clock clock;
  final void Function() onChange;
  final Duration latency;
}

/// Shared helpers. Mock repositories play the role of the backend: they
/// re-check permissions, enforce rules and write audit entries.
abstract class MockRepo {
  MockRepo(this.ctx);
  final MockContext ctx;

  MockDatabase get db => ctx.db;
  DateTime get now => ctx.clock.now();

  Future<void> wait([Duration? d]) {
    final delay = d ?? ctx.latency;
    return delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);
  }

  void commit() {
    db.persist();
    ctx.onChange();
  }

  AppUser userById(String id) {
    for (final u in db.users) {
      if (u.id == id) return u;
    }
    throw const NotFoundFailure('account');
  }

  StudioSpace spaceById(String id) {
    for (final s in db.spaces) {
      if (s.id == id) return s;
    }
    throw const NotFoundFailure('space');
  }

  /// Re-reads the actor from storage so stale client copies cannot grant
  /// permissions the account no longer has.
  AppUser fresh(AppUser actor) => userById(actor.id);

  void requireAdmin(AppUser actor) {
    if (!fresh(actor).isAdmin) throw const Forbidden('admin only');
  }

  void requirePermission(AppUser actor, StaffPermission p, {String? studioId}) {
    final u = fresh(actor);
    if (!PermissionPolicy.can(u, p)) throw Forbidden(p.name);
    if (studioId != null && !PermissionPolicy.managesStudio(u, studioId)) {
      throw const Forbidden('outside your studios');
    }
  }

  Booking bookingById(String id) {
    for (final b in db.bookings) {
      if (b.id == id) return b;
    }
    throw const NotFoundFailure('booking');
  }

  void putBooking(Booking b) {
    final i = db.bookings.indexWhere((x) => x.id == b.id);
    if (i < 0) {
      db.bookings.add(b);
    } else {
      db.bookings[i] = b;
    }
  }

  List<Payment> paymentsOf(String bookingId) =>
      db.payments.where((p) => p.bookingId == bookingId).toList();

  Money refundedOf(String bookingId) => db.refunds
      .where((r) => r.bookingId == bookingId)
      .fold(Money.zero, (sum, r) => sum + r.refunded);

  /// Recomputes a booking's payment status from its ledger.
  void recomputePayment(String bookingId) {
    final b = bookingById(bookingId);
    putBooking(b.copyWith(
      paymentStatus: PaymentCalculator.statusFor(
        total: b.pricing.total,
        payments: paymentsOf(bookingId),
        refunded: refundedOf(bookingId),
      ),
      updatedAt: now,
    ));
  }

  /// Releases expired holds. Called before any availability-sensitive read.
  int sweepHolds() {
    var count = 0;
    for (final b in List<Booking>.from(db.bookings)) {
      final hold = b.holdExpiresAt;
      if (hold == null || b.status != BookingStatus.pendingReview) continue;
      if (now.isBefore(hold)) continue;
      final pays = paymentsOf(b.id);
      if (pays.any((p) =>
          p.status == TransactionStatus.pendingVerification ||
          p.status == TransactionStatus.initiated)) {
        continue; // waiting on gateway verification
      }
      if (PaymentCalculator.verifiedPaid(pays).isPositive) {
        putBooking(b.copyWith(clearHold: true));
        continue;
      }
      putBooking(b.copyWith(
        status: BookingStatus.expired,
        clearHold: true,
        updatedAt: now,
        timeline: [
          ...b.timeline,
          TimelineEvent(
            at: now,
            title: 'Reservation expired',
            actor: 'System',
            note: 'The payment window ended and the slots were released.',
          ),
        ],
      ));
      count++;
    }
    if (count > 0) db.persist();
    return count;
  }

  List<BusyInterval> busyFor(String spaceId) {
    final busy = <BusyInterval>[];
    for (final b in db.bookings) {
      if (!b.status.occupiesSlot) continue;
      final kind = b.status == BookingStatus.pendingReview
          ? SlotState.pending
          : SlotState.confirmed;
      for (final item in b.items) {
        if (item.spaceId == spaceId) busy.add(BusyInterval(item.schedule, kind));
      }
    }
    for (final block in db.blocks) {
      if (block.spaceId == spaceId) {
        busy.add(BusyInterval(
          BookingSchedule(start: block.start, end: block.end),
          SlotState.unavailable,
        ));
      }
    }
    return busy;
  }

  void audit(AppUser actor, String action, String target,
      {String? detail, bool sensitive = false}) {
    db.audit.insert(
      0,
      AuditLog(
        id: db.newId('au'),
        actorId: actor.id,
        actorName: actor.fullName,
        actorRole: actor.role,
        action: action,
        target: target,
        detail: detail,
        sensitive: sensitive,
        at: now,
      ),
    );
  }

  void notifyUser(String userId, String title, String body, String type, {String? refId}) {
    db.notifications.insert(
      0,
      AppNotification(
        id: db.newId('nt'),
        userId: userId,
        title: title,
        body: body,
        type: type,
        refId: refId,
        createdAt: now,
      ),
    );
  }

  /// Notifies managers whose scope covers [studioIds] (and who hold
  /// [needs], if given), plus every administrator.
  void notifyStaff(Set<String> studioIds, String title, String body, String type,
      {String? refId, StaffPermission? needs}) {
    for (final u in db.users) {
      if (u.isAdmin) {
        notifyUser(u.id, title, body, type, refId: refId);
      } else if (u.isManager &&
          u.status == AccountStatus.active &&
          studioIds.any((s) => PermissionPolicy.managesStudio(u, s)) &&
          (needs == null || PermissionPolicy.can(u, needs))) {
        notifyUser(u.id, title, body, type, refId: refId);
      }
    }
  }
}

