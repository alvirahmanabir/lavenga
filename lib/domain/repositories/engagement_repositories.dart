import '../../core/money/money.dart';
import '../enums.dart';
import '../models/booking.dart';
import '../models/catalogue.dart';
import '../models/promo_social.dart';
import '../models/user.dart';

abstract class FavoriteRepository {
  Future<Set<String>> favoriteIds(String userId);
  Future<bool> toggle(String userId, String spaceId);
  Future<List<StudioSpace>> listFavorites(String userId);
  Future<List<StudioSpace>> recentlyViewed(String userId);
  Future<void> markViewed(String userId, String spaceId);
}

class ReviewableItem {
  const ReviewableItem(this.booking, this.item);
  final Booking booking;
  final BookingItem item;
}

abstract class ReviewRepository {
  Future<List<Review>> forSpace(String spaceId);
  Future<List<Review>> forCustomer(String customerId);
  Future<List<Review>> listForStaff({required AppUser actor});

  /// Completed booking items this customer has not reviewed yet.
  Future<List<ReviewableItem>> eligibleItems(String customerId);
  Future<Review> submit({
    required String bookingId,
    required String itemId,
    required int rating,
    required String comment,
    required AppUser actor,
  });
}

abstract class SupportRepository {
  Future<List<SupportTicket>> listForCustomer(String customerId);
  Future<List<SupportTicket>> listForStaff({required AppUser actor});
  Future<SupportTicket> get(String id);
  Future<SupportTicket> create({
    required AppUser customer,
    required String category,
    required String subject,
    required String body,
    String? bookingId,
  });
  Future<SupportTicket> reply(String ticketId, String body, {required AppUser actor});
  Future<SupportTicket> setStatus(String ticketId, TicketStatus status,
      {required AppUser actor});
  Future<void> markRead(String ticketId);
}

abstract class NotificationRepository {
  Future<List<AppNotification>> list(String userId);
  Future<int> unreadCount(String userId);
  Future<void> markRead(String id);
  Future<void> markAllRead(String userId);
}

class RankedItem {
  const RankedItem(this.label, this.amount, this.count);
  final String label;
  final Money amount;
  final int count;
}

class ManagerStat {
  const ManagerStat(this.name, this.handled, this.confirmed, this.cancelled);
  final String name;
  final int handled;
  final int confirmed;
  final int cancelled;
}

class DayValue {
  const DayValue(this.day, this.amount, this.count);
  final DateTime day;
  final Money amount;
  final int count;
}

/// Booking value, collected payments, outstanding dues and refunds are
/// always separate figures.
class DashboardStats {
  const DashboardStats({
    required this.totalBookings,
    required this.todayBookings,
    required this.upcomingBookings,
    required this.pendingConfirmations,
    required this.activeBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.bookingValue,
    required this.collected,
    required this.outstanding,
    required this.refunded,
    required this.pendingRefunds,
    required this.openTickets,
    required this.escalatedTickets,
    this.totalCustomers = 0,
    this.totalManagers = 0,
    this.totalStudios = 0,
    this.totalSpaces = 0,
    this.daily = const [],
    this.topSpaces = const [],
    this.topCustomers = const [],
    this.managerPerformance = const [],
  });

  final int totalBookings;
  final int todayBookings;
  final int upcomingBookings;
  final int pendingConfirmations;
  final int activeBookings;
  final int completedBookings;
  final int cancelledBookings;
  final Money bookingValue;
  final Money collected;
  final Money outstanding;
  final Money refunded;
  final int pendingRefunds;
  final int openTickets;
  final int escalatedTickets;
  final int totalCustomers;
  final int totalManagers;
  final int totalStudios;
  final int totalSpaces;
  final List<DayValue> daily;
  final List<RankedItem> topSpaces;
  final List<RankedItem> topCustomers;
  final List<ManagerStat> managerPerformance;
}

enum ReportKind { dailyBookings, monthlyBookings, collections, outstanding, spacePerformance }

class ReportData {
  const ReportData({
    required this.title,
    required this.headers,
    required this.rows,
    this.summary = const {},
  });
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final Map<String, String> summary;

  /// Preview of what a server-generated export would contain.
  String toCsv() {
    String esc(String v) => v.contains(',') || v.contains('"')
        ? '"${v.replaceAll('"', '""')}"'
        : v;
    final buffer = StringBuffer(headers.map(esc).join(','))..writeln();
    for (final r in rows) {
      buffer.writeln(r.map(esc).join(','));
    }
    return buffer.toString();
  }
}

abstract class ManagerRepository {
  /// Metrics limited to the manager's assigned studios.
  Future<DashboardStats> dashboard(AppUser actor, {DateTime? from, DateTime? to});
  Future<ReportData> report(AppUser actor, ReportKind kind, {DateTime? from, DateTime? to});
}

abstract class AdminRepository {
  Future<DashboardStats> dashboard(AppUser actor, {DateTime? from, DateTime? to});
  Future<ReportData> report(AppUser actor, ReportKind kind, {DateTime? from, DateTime? to});
  Future<List<AuditLog>> auditLogs({bool sensitiveOnly = false, UserRole? role, bool loginsOnly = false});
  Future<PlatformSettings> getSettings();
  Future<PlatformSettings> saveSettings(PlatformSettings settings, {required AppUser actor});
  Future<void> resetDemoData();
}
