import '../../core/errors/app_failure.dart';
import '../../domain/enums.dart';
import '../../domain/models/booking.dart';
import '../../domain/models/promo_social.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/engagement_repositories.dart';
import '../../domain/services/policies.dart';
import 'mock_context.dart';

class MockReviewRepository extends MockRepo implements ReviewRepository {
  MockReviewRepository(super.ctx);

  @override
  Future<List<Review>> forSpace(String spaceId) async =>
      db.reviews.where((r) => r.spaceId == spaceId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Review>> forCustomer(String customerId) async =>
      db.reviews.where((r) => r.customerId == customerId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<Review>> listForStaff({required AppUser actor}) async {
    final user = fresh(actor);
    if (user.isCustomer) throw const Forbidden('reviews');
    return db.reviews.where((r) {
      if (user.isAdmin) return true;
      final space = spaceById(r.spaceId);
      return PermissionPolicy.managesStudio(user, space.studioId);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<ReviewableItem>> eligibleItems(String customerId) async {
    final reviewed = {for (final r in db.reviews) r.itemId};
    final out = <ReviewableItem>[];
    for (final b in db.bookings) {
      if (b.customerId != customerId || b.status != BookingStatus.completed) continue;
      for (final item in b.items) {
        if (!reviewed.contains(item.id)) out.add(ReviewableItem(b, item));
      }
    }
    out.sort((a, b) => b.item.schedule.start.compareTo(a.item.schedule.start));
    return out;
  }

  @override
  Future<Review> submit({
    required String bookingId,
    required String itemId,
    required int rating,
    required String comment,
    required AppUser actor,
  }) async {
    await wait();
    final user = fresh(actor);
    final b = bookingById(bookingId);
    if (b.customerId != user.id) throw const Forbidden('not your booking');
    if (b.status != BookingStatus.completed) {
      throw const ValidationFailure('You can review a booking once it is completed');
    }
    final idx = b.items.indexWhere((i) => i.id == itemId);
    if (idx < 0) throw const NotFoundFailure('booking item');
    if (db.reviews.any((r) => r.itemId == itemId)) {
      throw const ValidationFailure('You have already reviewed this booking');
    }
    if (rating < 1 || rating > 5) throw const ValidationFailure('Choose a rating from 1 to 5');
    if (comment.trim().length < 10) {
      throw const ValidationFailure('Share a little more (at least 10 characters)', field: 'comment');
    }
    final item = b.items[idx];
    final review = Review(
      id: db.newId('rv'),
      bookingId: bookingId,
      itemId: itemId,
      spaceId: item.spaceId,
      customerId: user.id,
      customerName: user.fullName,
      rating: rating,
      comment: comment.trim(),
      createdAt: now,
    );
    db.reviews.add(review);

    final si = db.spaces.indexWhere((s) => s.id == item.spaceId);
    if (si >= 0) {
      final all = db.reviews.where((r) => r.spaceId == item.spaceId).toList();
      final avg = all.fold<int>(0, (sum, r) => sum + r.rating) / all.length;
      db.spaces[si] = db.spaces[si].copyWith(ratingAvg: avg, ratingCount: all.length);
    }
    notifyStaff({item.studioId}, 'New review',
        '${user.fullName} rated ${item.spaceName} $rating★.', 'review');
    commit();
    return review;
  }
}

class MockSupportRepository extends MockRepo implements SupportRepository {
  MockSupportRepository(super.ctx);

  SupportTicket _ticket(String id) {
    for (final t in db.tickets) {
      if (t.id == id) return t;
    }
    throw const NotFoundFailure('ticket');
  }

  void _put(SupportTicket t) {
    db.tickets[db.tickets.indexWhere((x) => x.id == t.id)] = t;
  }

  @override
  Future<List<SupportTicket>> listForCustomer(String customerId) async =>
      db.tickets.where((t) => t.customerId == customerId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<List<SupportTicket>> listForStaff({required AppUser actor}) async {
    final user = fresh(actor);
    if (user.isCustomer) throw const Forbidden('support');
    if (user.isManager) requirePermission(user, StaffPermission.handleSupport);
    return db.tickets.where((t) {
      if (user.isAdmin) return true;
      if (t.bookingId == null) return true;
      return PermissionPolicy.canSeeBooking(user, bookingById(t.bookingId!));
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<SupportTicket> get(String id) async => _ticket(id);

  @override
  Future<SupportTicket> create({
    required AppUser customer,
    required String category,
    required String subject,
    required String body,
    String? bookingId,
  }) async {
    await wait();
    final user = fresh(customer);
    if (subject.trim().length < 4) {
      throw const ValidationFailure('Add a short subject', field: 'subject');
    }
    if (body.trim().length < 10) {
      throw const ValidationFailure('Describe the issue (at least 10 characters)', field: 'body');
    }
    Booking? booking;
    if (bookingId != null) {
      booking = bookingById(bookingId);
      if (booking.customerId != user.id) throw const Forbidden('not your booking');
    }
    final id = db.newId('tk');
    final ticket = SupportTicket(
      id: id,
      reference: 'TK-${db.counter}',
      customerId: user.id,
      customerName: user.fullName,
      category: category,
      subject: subject.trim(),
      status: TicketStatus.awaitingStaff,
      bookingId: booking?.id,
      bookingRef: booking?.reference,
      messages: [
        SupportMessage(
          id: db.newId('msg'),
          senderId: user.id,
          senderName: user.fullName,
          senderRole: UserRole.customer,
          body: body.trim(),
          at: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    db.tickets.add(ticket);
    notifyStaff(booking?.studioIds ?? db.studios.map((s) => s.id).toSet(), 'New support ticket',
        '${user.fullName}: ${subject.trim()}', 'support',
        refId: id, needs: StaffPermission.handleSupport);
    commit();
    return ticket;
  }

  @override
  Future<SupportTicket> reply(String ticketId, String body, {required AppUser actor}) async {
    await wait();
    final user = fresh(actor);
    final t = _ticket(ticketId);
    if (user.isCustomer && t.customerId != user.id) throw const Forbidden('not your ticket');
    if (user.isManager) requirePermission(user, StaffPermission.handleSupport);
    if (body.trim().isEmpty) throw const ValidationFailure('Write a message first');
    if (t.status == TicketStatus.closed) {
      throw const ValidationFailure('This ticket is closed. Open a new one if you still need help.');
    }
    final fromCustomer = user.isCustomer;
    final updated = t.copyWith(
      messages: [
        ...t.messages,
        SupportMessage(
          id: db.newId('msg'),
          senderId: user.id,
          senderName: user.fullName,
          senderRole: user.role,
          body: body.trim(),
          at: now,
        ),
      ],
      status: fromCustomer
          ? (t.status == TicketStatus.escalated ? TicketStatus.escalated : TicketStatus.awaitingStaff)
          : (t.status == TicketStatus.escalated ? TicketStatus.escalated : TicketStatus.awaitingCustomer),
      unreadForCustomer: !fromCustomer,
      updatedAt: now,
    );
    _put(updated);
    if (!fromCustomer) {
      notifyUser(t.customerId, 'Support replied', '${t.reference}: ${body.trim()}', 'support',
          refId: t.id);
    }
    commit();
    return updated;
  }

  @override
  Future<SupportTicket> setStatus(String ticketId, TicketStatus status,
      {required AppUser actor}) async {
    await wait();
    final user = fresh(actor);
    final t = _ticket(ticketId);
    if (user.isCustomer) {
      if (t.customerId != user.id || status != TicketStatus.closed) {
        throw const Forbidden('ticket status');
      }
    } else if (user.isManager) {
      requirePermission(user, StaffPermission.handleSupport);
    }
    final updated = t.copyWith(status: status, updatedAt: now);
    _put(updated);
    if (status == TicketStatus.escalated) {
      audit(user, 'Escalated ticket', t.reference, sensitive: true);
      notifyStaff(const <String>{}, 'Ticket escalated', '${t.reference}: ${t.subject}', 'support',
          refId: t.id);
    }
    commit();
    return updated;
  }

  @override
  Future<void> markRead(String ticketId) async {
    final t = _ticket(ticketId);
    if (t.unreadForCustomer) {
      _put(t.copyWith(unreadForCustomer: false));
      db.persist();
    }
  }
}

class MockNotificationRepository extends MockRepo implements NotificationRepository {
  MockNotificationRepository(super.ctx);

  @override
  Future<List<AppNotification>> list(String userId) async =>
      db.notifications.where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<int> unreadCount(String userId) async =>
      db.notifications.where((n) => n.userId == userId && !n.read).length;

  @override
  Future<void> markRead(String id) async {
    final i = db.notifications.indexWhere((n) => n.id == id);
    if (i >= 0) {
      db.notifications[i] = db.notifications[i].copyWith(read: true);
      commit();
    }
  }

  @override
  Future<void> markAllRead(String userId) async {
    for (var i = 0; i < db.notifications.length; i++) {
      if (db.notifications[i].userId == userId) {
        db.notifications[i] = db.notifications[i].copyWith(read: true);
      }
    }
    commit();
  }
}
