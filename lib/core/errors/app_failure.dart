/// Typed failures that repositories throw. The UI maps them to messages in
/// one place ([AppFailure.userMessage]); these mirror the SRS error list.
sealed class AppFailure implements Exception {
  const AppFailure();

  String get userMessage;

  /// Whether a retry button makes sense. Never retry payment mutations blindly.
  bool get retryable => false;

  @override
  String toString() => '$runtimeType: $userMessage';
}

class SessionExpired extends AppFailure {
  const SessionExpired();
  @override
  String get userMessage => 'Your session has expired. Please sign in again.';
}

class Forbidden extends AppFailure {
  const Forbidden([this.action]);
  final String? action;
  @override
  String get userMessage => "You don't have permission to do that.";
}

class SlotConflict extends AppFailure {
  const SlotConflict([this.detail]);
  final String? detail;
  @override
  String get userMessage =>
      detail ?? 'That time was just taken. Please choose another slot.';
}

class HoldExpired extends AppFailure {
  const HoldExpired();
  @override
  String get userMessage =>
      'Your reservation timer ended and the slot was released. Please select it again.';
}

class PriceChanged extends AppFailure {
  const PriceChanged();
  @override
  String get userMessage =>
      'The price changed since you started. Please review the updated total.';
}

class PaymentPending extends AppFailure {
  const PaymentPending();
  @override
  String get userMessage =>
      'Your payment is still being verified. We will update your booking shortly.';
}

class NetworkFailure extends AppFailure {
  const NetworkFailure();
  @override
  String get userMessage => 'No connection. Check your network and try again.';
  @override
  bool get retryable => true;
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(this.message, {this.field});
  final String message;
  final String? field;
  @override
  String get userMessage => message;
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([this.what = 'item']);
  final String what;
  @override
  String get userMessage => 'This $what is no longer available.';
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([this.cause]);
  final Object? cause;
  @override
  String get userMessage => 'Something went wrong. Please try again.';
  @override
  bool get retryable => true;
}

/// Converts any thrown object into an [AppFailure].
AppFailure toFailure(Object error) =>
    error is AppFailure ? error : UnknownFailure(error);
