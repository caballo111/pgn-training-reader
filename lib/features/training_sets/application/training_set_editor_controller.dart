import 'package:flutter/foundation.dart';

import '../../../core/time/app_clock.dart';
import '../../../core/utilities/id_generator.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/pgn_block_index.dart';
import '../../../domain/training/training_set_repository.dart';
import '../../../domain/training/training_set.dart';
import '../../../domain/training/training_set_item.dart';

enum TrainingSetEditorStatus { idle, saving, saved, failed }

final class TrainingSetEditorState {
  TrainingSetEditorState({
    this.name = '',
    List<TrainingSetItem> items = const [],
    this.status = TrainingSetEditorStatus.idle,
    this.validationMessage,
    this.errorMessage,
  }) : items = List.unmodifiable(items);

  final String name;
  final List<TrainingSetItem> items;
  final TrainingSetEditorStatus status;
  final String? validationMessage;
  final String? errorMessage;
  bool get isSaving => status == TrainingSetEditorStatus.saving;
}

/// Owns an editable training-set draft and persists it on explicit save.
final class TrainingSetEditorController extends ChangeNotifier {
  TrainingSetEditorController({
    required this.repository,
    required this.clock,
    required this.idGenerator,
    TrainingSet? set,
  }) : _original = set,
       _state = TrainingSetEditorState(
         name: set?.name ?? '',
         items: set?.items ?? const [],
       );

  final TrainingSetRepository repository;
  final AppClock clock;
  final IdGenerator idGenerator;
  final TrainingSet? _original;
  TrainingSetEditorState _state;
  TrainingSetEditorState get state => _state;

  void setName(String value) {
    _emit(TrainingSetEditorState(name: value, items: _state.items));
  }

  void add(PgnBlockIndex block) {
    if (_hasDuplicateExerciseId(block)) {
      _emit(
        TrainingSetEditorState(
          name: _state.name,
          items: _state.items,
          validationMessage: 'This item has a duplicate exercise ID and cannot be added until the PGN is corrected.',
        ),
      );
      return;
    }
    if (_hasUnavailableContent(block)) {
      final message = block.parseStatus == PgnBlockParseStatus.malformed
          ? 'Malformed content cannot be added.'
          : 'Unsupported content cannot be added.';
      _emit(
        TrainingSetEditorState(
          name: _state.name,
          items: _state.items,
          validationMessage: message,
        ),
      );
      return;
    }
    if (_state.items.any((item) => item.blockId == block.id)) {
      _emit(
        TrainingSetEditorState(
          name: _state.name,
          items: _state.items,
          validationMessage: 'This item is already in the set.',
        ),
      );
      return;
    }
    final setId = _original?.id ?? 'draft';
    final items = [
      ..._state.items,
      TrainingSetItem(
        id: idGenerator.generateId(),
        trainingSetId: setId,
        blockId: block.id,
        position: _state.items.length,
        contentType: block.contentType,
        addedAt: clock.utcNow,
      ),
    ];
    _emit(
      TrainingSetEditorState(
        name: _state.name,
        items: _reposition(items, setId),
      ),
    );
  }

  /// Adds every eligible block once and returns a summary for the builder.
  Map<String, int> addMany(
    Iterable<PgnBlockIndex> blocks, {
    Set<String> unavailableBlockIds = const {},
  }) {
    var added = 0,
        duplicates = 0,
        malformed = 0,
        unsupported = 0,
        unavailable = 0;
    final items = List<TrainingSetItem>.of(_state.items);
    final blockIds = items.map((item) => item.blockId).toSet();
    final setId = _original?.id ?? 'draft';
    for (final block in blocks) {
      if (blockIds.contains(block.id)) {
        duplicates++;
      } else if (block.parseStatus == PgnBlockParseStatus.malformed) {
        malformed++;
      } else if (block.contentType == ContentType.unsupported ||
          block.parseStatus == PgnBlockParseStatus.unsupported) {
        unsupported++;
      } else if (_hasDuplicateExerciseId(block) ||
          unavailableBlockIds.contains(block.id)) {
        unavailable++;
      } else {
        items.add(
          TrainingSetItem(
            id: idGenerator.generateId(),
            trainingSetId: setId,
            blockId: block.id,
            position: items.length,
            contentType: block.contentType,
            addedAt: clock.utcNow,
          ),
        );
        blockIds.add(block.id);
        added++;
      }
    }
    _emit(
      TrainingSetEditorState(
        name: _state.name,
        items: _reposition(items, setId),
        validationMessage:
            'Added $added; $duplicates already selected; $malformed malformed; $unsupported unsupported; $unavailable unavailable.',
      ),
    );
    return {
      'added': added,
      'duplicates': duplicates,
      'malformed': malformed,
      'unsupported': unsupported,
      'unavailable': unavailable,
    };
  }

  static bool _hasDuplicateExerciseId(PgnBlockIndex block) =>
      block.diagnosticSummary == 'duplicateExerciseId';

  static bool _hasUnavailableContent(PgnBlockIndex block) =>
      block.contentType == ContentType.unsupported ||
      block.parseStatus == PgnBlockParseStatus.malformed ||
      block.parseStatus == PgnBlockParseStatus.unsupported;

  void remove(String itemId) {
    final setId = _original?.id ?? 'draft';
    final items = _state.items.where((item) => item.id != itemId).toList();
    _emit(
      TrainingSetEditorState(
        name: _state.name,
        items: _reposition(items, setId),
      ),
    );
  }

  void reorder(int oldIndex, int newIndex) {
    final items = [..._state.items];
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    _emit(
      TrainingSetEditorState(
        name: _state.name,
        items: _reposition(items, _original?.id ?? 'draft'),
      ),
    );
  }

  Future<bool> save() async {
    final name = _state.name.trim();
    if (name.isEmpty) {
      _emit(
        TrainingSetEditorState(
          name: _state.name,
          items: _state.items,
          validationMessage: 'Enter a name for this training set.',
        ),
      );
      return false;
    }
    if (_state.items.isEmpty) {
      _emit(
        TrainingSetEditorState(
          name: _state.name,
          items: _state.items,
          validationMessage: 'Add at least one item to this training set.',
        ),
      );
      return false;
    }
    _emit(
      TrainingSetEditorState(
        name: name,
        items: _state.items,
        status: TrainingSetEditorStatus.saving,
      ),
    );
    try {
      final now = clock.utcNow;
      if (_original == null) {
        final id = idGenerator.generateId();
        final items = _state.items
            .map(
              (item) => TrainingSetItem(
                id: item.id,
                trainingSetId: id,
                blockId: item.blockId,
                position: item.position,
                contentType: item.contentType,
                addedAt: item.addedAt,
              ),
            )
            .toList();
        await repository.createSet(
          TrainingSet(
            id: id,
            name: name,
            items: items,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        final originalIds = _original.items.map((item) => item.id).toSet();
        final draftIds = _state.items.map((item) => item.id).toSet();
        for (final item in _original.items.where(
          (item) => !draftIds.contains(item.id),
        )) {
          await repository.removeItem(
            trainingSetId: _original.id,
            itemId: item.id,
          );
        }
        for (final item in _state.items.where(
          (item) => !originalIds.contains(item.id),
        )) {
          await repository.addItem(
            TrainingSetItem(
              id: item.id,
              trainingSetId: _original.id,
              blockId: item.blockId,
              position: item.position,
              contentType: item.contentType,
              addedAt: item.addedAt,
            ),
          );
        }
        await repository.reorderItems(
          trainingSetId: _original.id,
          orderedItemIds: _state.items.map((item) => item.id).toList(),
        );
        if (name != _original.name) {
          await repository.renameSet(
            id: _original.id,
            name: name,
            updatedAt: now,
          );
        }
      }
      _emit(
        TrainingSetEditorState(
          name: name,
          items: _state.items,
          status: TrainingSetEditorStatus.saved,
        ),
      );
      return true;
    } catch (error) {
      _emit(
        TrainingSetEditorState(
          name: name,
          items: _state.items,
          status: TrainingSetEditorStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  static List<TrainingSetItem> _reposition(
    List<TrainingSetItem> items,
    String setId,
  ) => [
    for (var i = 0; i < items.length; i++)
      TrainingSetItem(
        id: items[i].id,
        trainingSetId: setId,
        blockId: items[i].blockId,
        position: i,
        contentType: items[i].contentType,
        addedAt: items[i].addedAt,
      ),
  ];

  void _emit(TrainingSetEditorState value) {
    _state = value;
    notifyListeners();
  }
}
