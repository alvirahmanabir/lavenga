import 'package:flutter_test/flutter_test.dart';
import 'package:lavenga/core/router/route_guard.dart';
import 'package:lavenga/core/session/session.dart';
import 'package:lavenga/domain/enums.dart';
import 'package:lavenga/domain/models/user.dart';

AppUser _u(UserRole role, {AccountStatus status = AccountStatus.active}) => AppUser(
      id: 'u',
      role: role,
      fullName: 'Test User',
      createdAt: DateTime.utc(2026, 1, 1),
      status: status,
    );

void main() {
  group('guardRedirect', () {
    test('not-ready session stays on splash', () {
      expect(guardRedirect(session: const SessionState(), location: '/c/home'), '/splash');
    });

    test('signed-out users are sent to login', () {
      const s = SessionState(ready: true);
      expect(guardRedirect(session: s, location: '/c/home'), '/auth/login');
      expect(guardRedirect(session: s, location: '/auth/login'), isNull);
    });

    test('signed-in users leave auth screens for their home', () {
      final s = SessionState(user: _u(UserRole.manager), ready: true);
      expect(guardRedirect(session: s, location: '/auth/login'), UserRole.manager.home);
    });

    test('roles cannot open each other\'s areas', () {
      final c = SessionState(user: _u(UserRole.customer), ready: true);
      final m = SessionState(user: _u(UserRole.manager), ready: true);
      final a = SessionState(user: _u(UserRole.admin), ready: true);
      expect(guardRedirect(session: c, location: '/a/dashboard'), UserRole.customer.home);
      expect(guardRedirect(session: m, location: '/a/orders'), UserRole.manager.home);
      expect(guardRedirect(session: a, location: '/a/orders'), isNull);
    });

    test('restricted accounts only see the restricted page', () {
      final s = SessionState(
          user: _u(UserRole.customer, status: AccountStatus.blacklisted), ready: true);
      expect(guardRedirect(session: s, location: '/c/home'), '/restricted');
      expect(guardRedirect(session: s, location: '/restricted'), isNull);
    });
  });
}
