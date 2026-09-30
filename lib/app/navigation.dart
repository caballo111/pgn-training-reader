import 'package:flutter/material.dart';

import 'app.dart';
import 'dependencies.dart';
import '../features/import_library/presentation/import_page.dart';

/// Route names used by the application shell.
abstract final class AppRoutes {
  static const library = '/';
  static const import = '/import';
}

/// Builds the initial route and provides a safe fallback for unknown routes.
Route<dynamic> onGenerateAppRoute(
  RouteSettings settings, {
  required AppDependencies dependencies,
}) {
  if (settings.name == AppRoutes.import) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ImportPage(controller: dependencies.importController),
    );
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const LibraryPage(),
  );
}
