import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/dependencies.dart';
import 'app/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (_) {
    // Keep startup available with the default theme. Platform exceptions can
    // contain private paths, so they must not be written to raw log sinks.
  }
  runApp(
    PgnTrainingReaderApp(
      dependencies: AppDependencies(
        themeController: ThemeController(preferences: preferences),
      ),
    ),
  );
}
