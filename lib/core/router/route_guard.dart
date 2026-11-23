import '../session/session.dart';

/// Pure redirect logic, unit-testable without a router.
/// Returns the location to redirect to, or null to allow [location].
String? guardRedirect({required SessionState session, required String location}) {
  if (location == '/splash') {
    return session.ready && session.isSignedIn ? _home(session) : null;
  }
  if (!session.ready) return '/splash';

  final isPublic = location == '/onboarding' || location.startsWith('/auth');
  final user = session.user;

  if (user == null) {
    return isPublic || location.startsWith('/dev') ? null : '/auth/login';
  }
  if (session.isRestricted) {
    return location == '/restricted' ? null : '/restricted';
  }
  if (location == '/restricted') return _home(session);
  if (isPublic) {
    // Allow completing a profile right after verification.
    return location == '/auth/complete-profile' ? null : _home(session);
  }
  if (location.startsWith('/dev')) return null;

  final prefix = user.role.prefix;
  final owns = location == prefix || location.startsWith('$prefix/');
  return owns ? null : _home(session);
}

String _home(SessionState s) => s.role!.home;
