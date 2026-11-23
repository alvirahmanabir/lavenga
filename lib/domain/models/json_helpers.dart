import '../../core/money/money.dart';

DateTime jDate(Object? v) => DateTime.parse(v as String).toUtc();
DateTime? jDateOpt(Object? v) => v == null ? null : jDate(v);
String? dateJson(DateTime? d) => d?.toUtc().toIso8601String();
Money jMoney(Object? v) => Money.fromMinor(v as int);
List<String> jStrings(Object? v) =>
    [for (final e in (v as List? ?? const [])) e as String];
Map<String, dynamic> jMap(Object? v) => Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> jList(Object? v) =>
    [for (final e in (v as List? ?? const [])) jMap(e)];
