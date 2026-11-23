/// Exact money value in minor units (BDT paisa). Never uses doubles.
class Money implements Comparable<Money> {
  const Money.fromMinor(this.minor);

  /// Whole taka, e.g. `Money.taka(2500)` is ৳2,500.00.
  const Money.taka(int taka) : minor = taka * 100;

  static const Money zero = Money.fromMinor(0);

  /// Parses "2500", "2500.5" or "2,500.50". Throws [FormatException].
  factory Money.parse(String input) {
    final cleaned = input.replaceAll(',', '').trim();
    final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
    if (match == null) throw FormatException('Invalid amount', input);
    final sign = match.group(1) == '-' ? -1 : 1;
    final whole = int.parse(match.group(2)!);
    final fraction = int.parse((match.group(3) ?? '0').padRight(2, '0'));
    return Money.fromMinor(sign * (whole * 100 + fraction));
  }

  final int minor;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money operator +(Money other) => Money.fromMinor(minor + other.minor);
  Money operator -(Money other) => Money.fromMinor(minor - other.minor);
  Money operator -() => Money.fromMinor(-minor);
  Money times(int factor) => Money.fromMinor(minor * factor);

  bool operator <(Money other) => minor < other.minor;
  bool operator <=(Money other) => minor <= other.minor;
  bool operator >(Money other) => minor > other.minor;
  bool operator >=(Money other) => minor >= other.minor;

  /// Percentage in basis points (1% = 100 bp), rounded half away from zero.
  Money percent(int basisPoints) {
    final product = minor * basisPoints;
    final sign = product < 0 ? -1 : 1;
    return Money.fromMinor(sign * ((product.abs() + 5000) ~/ 10000));
  }

  Money clampMin(Money floor) => this < floor ? floor : this;
  Money clampMax(Money ceiling) => this > ceiling ? ceiling : this;

  /// Splits this amount proportionally to [weights]; parts always sum to
  /// this amount exactly (remainder goes to the last part).
  List<Money> allocate(List<int> weights) {
    if (weights.isEmpty) return const [];
    final totalWeight = weights.fold<int>(0, (a, b) => a + b);
    if (totalWeight <= 0) {
      throw ArgumentError('Weights must sum to a positive number');
    }
    final parts = <int>[
      for (final w in weights) (minor * w) ~/ totalWeight,
    ];
    final assigned = parts.fold<int>(0, (a, b) => a + b);
    parts[parts.length - 1] += minor - assigned;
    return [for (final p in parts) Money.fromMinor(p)];
  }

  /// "৳12,500" or "৳12,500.50". Western digit grouping for now; locale-aware
  /// formatting (Bangla digits, lakh grouping) arrives with localization.
  String format({bool alwaysShowDecimals = false}) {
    final abs = minor.abs();
    final whole = (abs ~/ 100).toString();
    final fraction = abs % 100;
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final decimals = (fraction == 0 && !alwaysShowDecimals)
        ? ''
        : '.${fraction.toString().padLeft(2, '0')}';
    return '${minor < 0 ? '-' : ''}৳$grouped$decimals';
  }

  Map<String, dynamic> toJson() => {'minor': minor, 'currency': 'BDT'};
  factory Money.fromJson(Map<String, dynamic> json) =>
      Money.fromMinor(json['minor'] as int);

  @override
  int compareTo(Money other) => minor.compareTo(other.minor);

  @override
  bool operator ==(Object other) => other is Money && other.minor == minor;

  @override
  int get hashCode => minor.hashCode;

  @override
  String toString() => 'Money($minor)';
}
