import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/clock/clock.dart';
import 'core/di/providers.dart';
import 'data/local/local_store.dart';
import 'data/mock/mock_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Frontend phase: all data is mock, persisted locally. Replace the
  // repository bindings in core/di/providers.dart when Supabase arrives.
  final store = await PrefsLocalStore.open();
  final db = await MockDatabase.open(store, const SystemClock().now());
  runApp(ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      databaseProvider.overrideWithValue(db),
    ],
    child: const LavengaApp(),
  ));
}
