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
  } catch (error) {
    debugPrint('Could not load appearance preference: $error');
  }
  runApp(
    PgnTrainingReaderApp(
      dependencies: AppDependencies(
        themeController: ThemeController(preferences: preferences),
      ),
    ),
  );
}
