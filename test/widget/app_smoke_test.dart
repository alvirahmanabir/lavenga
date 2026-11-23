import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavenga/app.dart';
import 'package:lavenga/core/di/providers.dart';
import 'package:lavenga/data/local/local_store.dart';
import 'package:lavenga/data/mock/mock_database.dart';

void main() {
  testWidgets('app starts and shows the sign-in screen', (tester) async {
    final store = MemoryLocalStore();
    final db = MockDatabase.seeded(store, DateTime.utc(2026, 6, 1));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        mockLatencyProvider.overrideWithValue(Duration.zero),
      ],
      child: const LavengaApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(find.byType(LavengaApp), findsOneWidget);
  });
}
