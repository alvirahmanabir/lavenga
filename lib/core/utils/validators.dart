/// Frontend validators. Return null when valid, otherwise a message.
/// These are UX checks only; the backend validates again.
abstract final class Validators {
  static String? required(String? v, [String label = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  static String? minLength(String? v, int n, [String label = 'This field']) {
    final r = required(v, label);
    if (r != null) return r;
    return v!.trim().length < n ? '$label needs at least $n characters' : null;
  }

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static String? email(String? v) {
    final r = required(v, 'Email');
    if (r != null) return r;
    return _email.hasMatch(v!.trim()) ? null : 'Enter a valid email address';
  }

  /// Bangladesh mobile: 01XXXXXXXXX, +8801XXXXXXXXX or 8801XXXXXXXXX.
  static final _bdPhone = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');
  static String? phone(String? v, {bool requiredField = true}) {
    final value = (v ?? '').replaceAll(RegExp(r'[\s\-]'), '');
    if (value.isEmpty) return requiredField ? 'Phone number is required' : null;
    return _bdPhone.hasMatch(value) ? null : 'Enter a valid mobile number (e.g. 01712345678)';
  }

  static String? emailOrPhone(String? v) {
    final r = required(v, 'Email or phone');
    if (r != null) return r;
    final value = v!.trim();
    if (value.contains('@')) return email(value);
    return phone(value);
  }

  static String? password(String? v) {
    final r = required(v, 'Password');
    if (r != null) return r;
    if (v!.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include letters and numbers';
    }
    return null;
  }

  static String? Function(String?) matches(String Function() other) =>
      (v) => v == other() ? null : 'Passwords do not match';

  static String? otp(String? v) =>
      RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'Enter the 6-digit code';

  static String? fullName(String? v) => minLength(v, 3, 'Full name');
}
