import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/admin/admin.dart';
import '../../features/auth/auth.dart';
import '../../features/customer/booking/booking.dart';
import '../../features/customer/discovery/discovery.dart';
import '../../features/dev/widget_gallery_screen.dart';
import '../../features/staff/staff.dart';
import '../session/session.dart';
import '../widgets/adaptive_shell.dart';
import 'route_guard.dart';

const _customerTabs = [
  ShellDestination('Home', Icons.home_outlined, Icons.home, '/c/home'),
  ShellDestination('Explore', Icons.search, Icons.search, '/c/explore'),
  ShellDestination('Favourites', Icons.favorite_border, Icons.favorite, '/c/favourites'),
  ShellDestination('Bookings', Icons.event_note_outlined, Icons.event_note, '/c/bookings'),
  ShellDestination('Profile', Icons.person_outline, Icons.person, '/c/profile'),
];

const _managerTabs = [
  ShellDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/m/dashboard'),
  ShellDestination('Bookings', Icons.event_note_outlined, Icons.event_note, '/m/bookings'),
  ShellDestination('Spaces', Icons.meeting_room_outlined, Icons.meeting_room, '/m/spaces'),
  ShellDestination('Customers', Icons.people_outline, Icons.people, '/m/customers'),
  ShellDestination('More', Icons.more_horiz, Icons.more_horiz, '/m/more'),
];

const _adminTabs = [
  ShellDestination('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/a/dashboard'),
  ShellDestination('Orders', Icons.receipt_long_outlined, Icons.receipt_long, '/a/orders'),
  ShellDestination('Catalogue', Icons.store_outlined, Icons.store, '/a/catalogue'),
  ShellDestination('People', Icons.people_outline, Icons.people, '/a/people'),
  ShellDestination('More', Icons.more_horiz, Icons.more_horiz, '/a/more'),
];

String _id(GoRouterState s, [String key = 'id']) => s.pathParameters[key]!;
String? _q(GoRouterState s, String key) => s.uri.queryParameters[key];

StatefulShellRoute _shell(List<ShellDestination> tabs, Widget Function(int index) screen) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => AdaptiveShell(navigationShell: shell, destinations: tabs),
    branches: [
      for (var i = 0; i < tabs.length; i++)
        StatefulShellBranch(routes: [
          GoRoute(
            path: tabs[i].location,
            builder: (context, state) => screen(i),
          ),
        ]),
    ],
  );
}

/// Screens shared by manager and administrator under their own prefix.
List<GoRoute> _staffShared(String p) => [
      GoRoute(path: '$p/booking/:id', builder: (c, s) => StaffBookingDetailScreen(bookingId: _id(s))),
      GoRoute(
        path: '$p/space/:id/edit',
        builder: (c, s) => SpaceEditScreen(spaceId: _id(s), studioId: _q(s, 'studio')),
      ),
      GoRoute(path: '$p/customer/:id', builder: (c, s) => CustomerDetailScreen(customerId: _id(s))),
      GoRoute(path: '$p/refunds', builder: (c, s) => const RefundQueueScreen()),
      GoRoute(path: '$p/refund/:id', builder: (c, s) => StaffRefundDetailScreen(refundId: _id(s))),
      GoRoute(path: '$p/support', builder: (c, s) => const StaffSupportScreen()),
      GoRoute(path: '$p/support/:id', builder: (c, s) => StaffTicketScreen(ticketId: _id(s))),
      GoRoute(path: '$p/reports', builder: (c, s) => const ReportsScreen()),
      GoRoute(path: '$p/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '$p/profile', builder: (c, s) => const StaffProfileScreen()),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => guardRedirect(
      session: ref.read(sessionProvider),
      location: state.matchedLocation,
    ),
    routes: [
      // ---- Entry and auth ----
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/auth/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(
        path: '/auth/otp',
        builder: (c, s) => OtpScreen(userId: _q(s, 'uid') ?? '', mode: _q(s, 'mode') ?? 'verify'),
      ),
      GoRoute(path: '/auth/forgot', builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/auth/reset',
        builder: (c, s) => ResetPasswordScreen(userId: _q(s, 'uid') ?? '', code: _q(s, 'code') ?? ''),
      ),
      GoRoute(path: '/auth/complete-profile', builder: (c, s) => const CompleteProfileScreen()),
      GoRoute(path: '/restricted', builder: (c, s) => const RestrictedScreen()),
      GoRoute(path: '/dev/gallery', builder: (c, s) => const WidgetGalleryScreen()),

      // ---- Customer: shell tabs ----
      _shell(_customerTabs, (i) => switch (i) {
            0 => const CustomerHomeScreen(),
            1 => const ExploreScreen(),
            2 => const FavoritesScreen(),
            3 => const MyBookingsScreen(),
            _ => const ProfileScreen(),
          }),
      // Explore deep link with a category: /c/explore?category=cat_photo is
      // handled inside ExploreScreen via the `initialCategoryId` provider seed.
      GoRoute(path: '/c/category/:id', builder: (c, s) => ExploreScreen(initialCategoryId: _id(s))),
      GoRoute(path: '/c/search', builder: (c, s) => ExploreScreen(initialQuery: _q(s, 'q'), focusSearch: true)),
      GoRoute(path: '/c/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/c/offers', builder: (c, s) => const OffersScreen()),
      GoRoute(path: '/c/studios', builder: (c, s) => const StudioListScreen()),
      GoRoute(path: '/c/studio/:id', builder: (c, s) => StudioDetailScreen(studioId: _id(s))),
      GoRoute(path: '/c/space/:id', builder: (c, s) => SpaceDetailScreen(spaceId: _id(s))),
      GoRoute(
        path: '/c/gallery/:id',
        builder: (c, s) => GalleryScreen(
          spaceId: _id(s),
          initialIndex: int.tryParse(_q(s, 'i') ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/c/space/:id/reviews', builder: (c, s) => SpaceReviewsScreen(spaceId: _id(s))),
      GoRoute(path: '/c/schedule/:spaceId', builder: (c, s) => ScheduleScreen(spaceId: _id(s, 'spaceId'))),
      GoRoute(path: '/c/cart', builder: (c, s) => const CartScreen()),
      GoRoute(path: '/c/checkout', builder: (c, s) => const CheckoutScreen()),
      GoRoute(path: '/c/pay/:bookingId', builder: (c, s) => PaymentMethodScreen(bookingId: _id(s, 'bookingId'))),
      GoRoute(
        path: '/c/pay/:bookingId/processing',
        builder: (c, s) => PaymentProcessingScreen(
          bookingId: _id(s, 'bookingId'),
          paymentId: _q(s, 'p') ?? '',
        ),
      ),
      GoRoute(
        path: '/c/pay/:bookingId/success',
        builder: (c, s) => PaymentSuccessScreen(bookingId: _id(s, 'bookingId'), paymentId: _q(s, 'p') ?? ''),
      ),
      GoRoute(
        path: '/c/pay/:bookingId/failure',
        builder: (c, s) => PaymentFailureScreen(bookingId: _id(s, 'bookingId'), paymentId: _q(s, 'p') ?? ''),
      ),
      GoRoute(path: '/c/booking/:id', builder: (c, s) => BookingDetailScreen(bookingId: _id(s))),
      GoRoute(path: '/c/booking/:id/payments', builder: (c, s) => PaymentHistoryScreen(bookingId: _id(s))),
      GoRoute(path: '/c/payment/:id', builder: (c, s) => TransactionDetailScreen(paymentId: _id(s))),
      GoRoute(path: '/c/booking/:id/refund', builder: (c, s) => RefundRequestScreen(bookingId: _id(s))),
      GoRoute(path: '/c/refunds', builder: (c, s) => const RefundListScreen()),
      GoRoute(path: '/c/refund/:id', builder: (c, s) => CustomerRefundDetailScreen(refundId: _id(s))),
      GoRoute(
        path: '/c/review/:bookingId/:itemId',
        builder: (c, s) => WriteReviewScreen(bookingId: _id(s, 'bookingId'), itemId: _id(s, 'itemId')),
      ),
      GoRoute(path: '/c/reviews', builder: (c, s) => const MyReviewsScreen()),
      GoRoute(path: '/c/support', builder: (c, s) => const SupportInboxScreen()),
      GoRoute(path: '/c/support/new', builder: (c, s) => NewTicketScreen(bookingId: _q(s, 'booking'))),
      GoRoute(path: '/c/support/:id', builder: (c, s) => TicketConversationScreen(ticketId: _id(s))),
      GoRoute(path: '/c/profile/edit', builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: '/c/profile/password', builder: (c, s) => const ChangePasswordScreen()),
      GoRoute(path: '/c/profile/notifications', builder: (c, s) => const NotificationPrefsScreen()),
      GoRoute(path: '/c/policies', builder: (c, s) => const PoliciesScreen()),

      // ---- Manager ----
      _shell(_managerTabs, (i) => switch (i) {
            0 => const ManagerDashboardScreen(),
            1 => const StaffBookingsScreen(),
            2 => const StaffSpacesScreen(),
            3 => const StaffCustomersScreen(),
            _ => const StaffMoreScreen(),
          }),
      ..._staffShared('/m'),

      // ---- Administrator ----
      _shell(_adminTabs, (i) => switch (i) {
            0 => const AdminDashboardScreen(),
            1 => const StaffBookingsScreen(),
            2 => const AdminCatalogueScreen(),
            3 => const AdminPeopleScreen(),
            _ => const StaffMoreScreen(),
          }),
      ..._staffShared('/a'),
      GoRoute(path: '/a/studio/:id', builder: (c, s) => StudioFormScreen(studioId: _id(s))),
      GoRoute(path: '/a/manager/:id', builder: (c, s) => ManagerDetailScreen(managerId: _id(s))),
      GoRoute(path: '/a/promotions', builder: (c, s) => const PromotionsScreen()),
      GoRoute(path: '/a/discount/:id', builder: (c, s) => DiscountFormScreen(discountId: _id(s))),
      GoRoute(path: '/a/payments', builder: (c, s) => const PaymentsScreen()),
      GoRoute(path: '/a/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/a/settings/policies', builder: (c, s) => const PolicySettingsScreen()),
      GoRoute(path: '/a/settings/banners', builder: (c, s) => const BannersScreen()),
      GoRoute(path: '/a/audit', builder: (c, s) => const AuditLogScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
