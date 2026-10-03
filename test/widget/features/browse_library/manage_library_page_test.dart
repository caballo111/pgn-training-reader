import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pgntrainingreader/domain/chess_content/pgn_source.dart';
import 'package:pgntrainingreader/domain/library/library_lifecycle_service.dart';
import 'package:pgntrainingreader/domain/library/pgn_source_repository.dart';
import 'package:pgntrainingreader/features/browse_library/presentation/manage_library_page.dart';

void main() {
  testWidgets('adds a book through callback and refreshes the list', (
    tester,
  ) async {
    final sources = _Sources();
    var additions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ManageLibraryPage(
          sourceRepository: sources,
          onAddBook: () async {
            additions++;
            sources.values.add(_book('Second book', 'book-2'));
          },
          removeBook: (_) async => const LibraryRemovalResult(
            status: LibraryRemovalStatus.removed,
            message: 'Removed',
          ),
          pendingCleanupSourceIds: () async => const [],
          retryCleanup: (_) async => const LibraryRemovalResult(
            status: LibraryRemovalStatus.removed,
            message: 'Cleanup complete.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First book'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-book')));
    await tester.pumpAndSettle();
    expect(additions, 1);
    expect(find.text('Second book'), findsOneWidget);
  });

  testWidgets(
    'cancel leaves the source; confirmation names scope and removes',
    (tester) async {
      final sources = _Sources();
      final removedIds = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ManageLibraryPage(
            sourceRepository: sources,
            onAddBook: () async {},
            removeBook: (id) async {
              removedIds.add(id);
              sources.values.clear();
              return const LibraryRemovalResult(
                status: LibraryRemovalStatus.removed,
                message: 'Removed',
              );
            },
            pendingCleanupSourceIds: () async => const [],
            retryCleanup: (_) async => const LibraryRemovalResult(
              status: LibraryRemovalStatus.removed,
              message: 'Cleanup complete.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Book actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      expect(find.textContaining('“First book”'), findsOneWidget);
      expect(
        find.textContaining('Saved training history will be retained'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(removedIds, isEmpty);
      expect(find.text('First book'), findsOneWidget);

      await tester.tap(find.byTooltip('Book actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-remove-book')));
      await tester.pumpAndSettle();
      expect(removedIds, ['book-1']);
      expect(find.text('No books in your library yet.'), findsOneWidget);
    },
  );

  testWidgets('shows cleanup failure with a retry action', (tester) async {
    var attempts = 0;
    final sources = _Sources();
    await tester.pumpWidget(
      MaterialApp(
        home: ManageLibraryPage(
          sourceRepository: sources,
          onAddBook: () async {},
          removeBook: (_) async {
            attempts++;
            sources.values.clear();
            return const LibraryRemovalResult(
              status: LibraryRemovalStatus.cleanupFailed,
              message: 'Book removed; local copy cleanup needs retry.',
            );
          },
          pendingCleanupSourceIds: () async => const ['book-1'],
          retryCleanup: (_) async {
            attempts++;
            return const LibraryRemovalResult(
              status: LibraryRemovalStatus.cleanupFailed,
              message: 'Cleanup still needs retry.',
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Book actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove-book')));
    await tester.pumpAndSettle();
    expect(
      find.text('Book removed; local copy cleanup needs retry.'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Retry cleanup'),
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('long names and persistent cleanup retry fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final sources = _Sources();
    sources.values[0] = _book(
      'A very long book title that should wrap within the available space',
      'book-1',
    );
    sources.remember(
      _book('A removed book with a pending saved copy cleanup', 'book-2'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ManageLibraryPage(
          sourceRepository: sources,
          onAddBook: () async {},
          removeBook: (_) async => const LibraryRemovalResult(
            status: LibraryRemovalStatus.removed,
            message: 'Removed',
          ),
          pendingCleanupSourceIds: () async => const ['book-2'],
          retryCleanup: (_) async => const LibraryRemovalResult(
            status: LibraryRemovalStatus.removed,
            message: 'Cleanup complete.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('very long book title'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retry cleanup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _Sources implements PgnSourceRepository {
  _Sources() : values = [_book('First book', 'book-1')];
  final List<PgnSource> values;
  final Map<String, PgnSource> _known = {
    'book-1': _book('First book', 'book-1'),
  };

  void remember(PgnSource source) => _known[source.id] = source;

  @override
  Future<PgnSource?> getById(String id) async =>
      _known[id] ?? values.where((source) => source.id == id).firstOrNull;
  @override
  Future<List<PgnSource>> list() async => List.of(values);
  @override
  Future<void> create(PgnSource source) async {
    values.add(source);
    _known[source.id] = source;
  }

  @override
  Future<void> update(PgnSource source) async {}

  @override
  Future<void> remove({required String id, required DateTime removedAt}) async {
    values.removeWhere((source) => source.id == id);
  }

  @override
  Future<void> updateAfterVerifiedRelink({
    required PgnSource source,
    required String expectedFingerprint,
  }) async {}
}

PgnSource _book(String name, String id) => PgnSource(
  id: id,
  displayName: name,
  accessMode: PgnSourceAccessMode.managedCopy,
  managedPath: '0123456789abcdef0123456789abcdef',
  scannerVersion: 1,
  importState: 'indexed',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
