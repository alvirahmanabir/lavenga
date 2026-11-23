import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';
import '../../domain/models/user.dart';
import '../di/providers.dart';

export '../../domain/enums.dart' show UserRole, UserRoleX;

class SessionState {
  const SessionState({this.user, this.ready = false});

  final AppUser? user;

  /// False until the stored session has been restored (splash screen).
  final bool ready;

  UserRole? get role => user?.role;
  bool get isSignedIn => user != null;
  bool get isRestricted => user?.isRestricted ?? false;
}

/// Holds the signed-in user. All credential checks happen in AuthRepository
/// (mock now, Supabase Auth later); nothing sensitive is stored here.
class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Keep the user fresh after profile edits, blacklisting and so on.
    ref.listen(dbVersionProvider, (_, __) => _refresh());
    return const SessionState();
  }

  Future<void> restore() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    state = SessionState(user: user, ready: true);
  }

  /// Returns the user. If the account is unverified the session is NOT
  /// started and the caller must send the user to OTP verification.
  Future<AppUser> signIn(String identifier, String password) async {
    final user = await ref.read(authRepositoryProvider).signIn(
          identifier: identifier,
          password: password,
        );
    if (user.verified) state = SessionState(user: user, ready: true);
    return user;
  }

  Future<AppUser> register({
    required String fullName,
    required String password,
    String? email,
    String? phone,
  }) =>
      ref.read(authRepositoryProvider).register(
            fullName: fullName,
            password: password,
            email: email,
            phone: phone,
          );

  Future<void> verifyOtp(String userId, String code) async {
    final user = await ref.read(authRepositoryProvider).verifyOtp(userId: userId, code: code);
    state = SessionState(user: user, ready: true);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const SessionState(ready: true);
  }

  Future<void> _refresh() async {
    final current = state.user;
    if (current == null) return;
    try {
      final fresh = await ref.read(userRepositoryProvider).getUser(current.id);
      state = SessionState(user: fresh, ready: true);
    } catch (_) {
      // Account removed: leave as-is; next sign-in will fail cleanly.
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Non-null user for screens that only render when signed in.
final currentUserProvider = Provider<AppUser>((ref) {
  final user = ref.watch(sessionProvider).user;
  if (user == null) throw StateError('No signed-in user');
  return user;
});

/// "/c", "/m" or "/a" for the current role; use to build shared-screen links.
final rolePrefixProvider = Provider<String>((ref) {
  final role = ref.watch(sessionProvider).role;
  return role?.prefix ?? '/c';
});
