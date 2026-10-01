import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'audit rejects unsafe logging expressions in representative fixtures',
    () {
      for (final fixture in [
        'logger.log(AppLogEvent.importFailed, pgnText);',
        '_logger.log(event, solutionSan: answer);',
        'this.logger.log(event, managedPath: path);',
        'logger.log(event, contentUri: uri);',
        'developer.log(commentText);',
        'stdout.writeln(sourcePath);',
        'debugPrint(rawPgn);',
      ]) {
        expect(_unsafeLogging(fixture), isTrue, reason: fixture);
      }
      expect(
        _unsafeLogging(
          'logger.log(AppLogEvent.importProgress, itemCount: count);',
        ),
        isFalse,
      );
    },
  );

  test(
    'production code exposes only content-free logs and no raw log sinks',
    () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final violations = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        if (_unsafeLogging(source)) violations.add(file.path);
      }

      final loggerApi = File('lib/core/logging/app_logger.dart')
          .readAsStringSync();
      final recordFields = loggerApi
          .split('final class AppLogRecord')[1]
          .split('/// Receives operational events')[0];
      final loggerContract = loggerApi
          .split('abstract interface class AppLogger')[1]
          .split('/// Structured logger')[0];
      if (RegExp(r'\b(?:String|Object|dynamic|Map\s*<)')
              .hasMatch(recordFields) ||
          RegExp(r'\b(?:String|Object|dynamic|Map\s*<)')
              .hasMatch(loggerContract)) {
        violations.add(
          'lib/core/logging/app_logger.dart: unrestricted log field',
        );
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );
}

bool _unsafeLogging(String source) {
  if (RegExp(
    r'\b(?:debugPrint|print)\s*\(|\b(?:stdout|stderr)\s*\.\s*(?:write|writeln)\s*\(',
  ).hasMatch(source)) {
    return true;
  }
  final calls = RegExp(
    r'(?:\b\w+\s*\.\s*)?\blog\s*\(([^;]{0,1200})\)',
    dotAll: true,
  );
  for (final match in calls.allMatches(source)) {
    final args = match.group(1)!;
    if (RegExp("['\\\"]").hasMatch(args) || _hasSensitiveIdentifier(args)) {
      return true;
    }
  }
  return false;
}

bool _hasSensitiveIdentifier(String expression) {
  final words = RegExp(r'[A-Z]+(?=[A-Z][a-z]|\b)|[A-Z]?[a-z]+|[A-Z]+')
      .allMatches(expression)
      .map((match) => match.group(0)!.toLowerCase())
      .toSet();
  return words.intersection({
    'pgn',
    'comment',
    'san',
    'solution',
    'path',
    'uri',
    'source',
    'text',
  }).isNotEmpty;
}
