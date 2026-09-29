import 'package:flutter/material.dart';

import 'app.dart';

/// Route names used by the application shell.
abstract final class AppRoutes {
  static const library = '/';
}

/// Builds the initial route and provides a safe fallback for unknown routes.
Route<dynamic> onGenerateAppRoute(RouteSettings settings) {
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const LibraryPage(),
  );
}
