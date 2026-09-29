import '../core/logging/app_logger.dart';
import '../core/time/app_clock.dart';
import '../core/utilities/id_generator.dart';

/// Application-level composition root for foundational abstractions.
///
/// Feature services and persistence dependencies are added here as their
/// contracts are implemented. Callers may provide substitutes for tests.
final class AppDependencies {
  AppDependencies({
    AppClock? clock,
    IdGenerator? idGenerator,
    AppLogger? logger,
  }) : clock = clock ?? SystemAppClock(),
       idGenerator = idGenerator ?? RandomIdGenerator(),
       logger = logger ?? const StructuredAppLogger(_discardLogRecord);

  final AppClock clock;
  final IdGenerator idGenerator;
  final AppLogger logger;
}

void _discardLogRecord(AppLogRecord _) {}
