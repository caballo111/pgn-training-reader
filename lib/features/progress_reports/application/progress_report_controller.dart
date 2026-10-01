import 'package:flutter/foundation.dart';

import '../../../domain/training/cycle.dart';
import '../../../domain/training/progress_calculator.dart';
import '../../../domain/training/puzzle_interaction_repository.dart';
import '../../../domain/training/training_repository.dart';
import '../../../domain/training/training_set.dart';

enum ProgressReportStatus { loading, ready, failed }

/// Immutable selection and report data for the progress report screen.
@immutable
final class ProgressReportState {
  const ProgressReportState({
    this.status = ProgressReportStatus.loading,
    this.cycles = const [],
    this.selectedCycleId,
    this.comparisonCycleId,
    this.selectedSummary,
    this.comparison,
    this.comparisonCompatible = true,
    this.errorMessage,
  });

  final ProgressReportStatus status;
  final List<Cycle> cycles;
  final String? selectedCycleId;
  final String? comparisonCycleId;
  final ProgressSummary? selectedSummary;
  final ProgressComparison? comparison;
  final bool comparisonCompatible;
  final String? errorMessage;

  Cycle? get selectedCycle => _cycleFor(selectedCycleId);
  Cycle? get comparisonCycle => _cycleFor(comparisonCycleId);

  Cycle? _cycleFor(String? id) {
    if (id == null) return null;
    for (final cycle in cycles) {
      if (cycle.id == id) return cycle;
    }
    return null;
  }
}

/// Loads cycle reports and keeps the selected and comparison cycles in sync.
///
/// The repository supplies raw aggregates; all report metrics are delegated
/// to [ProgressCalculator] so the controller does not duplicate scoring rules.
final class ProgressReportController extends ChangeNotifier {
  ProgressReportController({
    required this.trainingSetId,
    required this.repository,
  });

  final String trainingSetId;
  final TrainingRepository repository;

  ProgressReportState _state = const ProgressReportState();
  ProgressReportState get state => _state;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_generation;
    _set(const ProgressReportState(status: ProgressReportStatus.loading));
    try {
      final cycles = await repository.listCycles(trainingSetId);
      if (!_current(generation)) return;

      // The most recent cycle is the natural default report. When possible,
      // compare it with the cycle immediately before it.
      final selectedId = cycles.isEmpty ? null : cycles.last.id;
      final comparisonId = cycles.length < 2
          ? null
          : cycles[cycles.length - 2].id;
      await _loadSelection(
        generation: generation,
        cycles: cycles,
        selectedCycleId: selectedId,
        comparisonCycleId: comparisonId,
      );
    } catch (_) {
      if (_current(generation)) _fail();
    }
  }

  Future<void> refresh() => load();

  Future<void> selectCycle(String cycleId) async {
    if (!_state.cycles.any((cycle) => cycle.id == cycleId)) return;
    final generation = ++_generation;
    await _loadSelection(
      generation: generation,
      cycles: _state.cycles,
      selectedCycleId: cycleId,
      comparisonCycleId: _state.comparisonCycleId == cycleId
          ? null
          : _state.comparisonCycleId,
    );
  }

  Future<void> selectComparisonCycle(String? cycleId) async {
    if (cycleId != null &&
        (!_state.cycles.any((cycle) => cycle.id == cycleId) ||
            cycleId == _state.selectedCycleId)) {
      return;
    }
    final generation = ++_generation;
    await _loadSelection(
      generation: generation,
      cycles: _state.cycles,
      selectedCycleId: _state.selectedCycleId,
      comparisonCycleId: cycleId,
    );
  }

  Future<void> _loadSelection({
    required int generation,
    required List<Cycle> cycles,
    required String? selectedCycleId,
    required String? comparisonCycleId,
  }) async {
    _set(
      ProgressReportState(
        status: ProgressReportStatus.loading,
        cycles: List.unmodifiable(cycles),
        selectedCycleId: selectedCycleId,
        comparisonCycleId: comparisonCycleId,
      ),
    );
    try {
      final selectedFuture = selectedCycleId == null
          ? null
          : repository.aggregateForCycle(selectedCycleId);
      final comparisonFuture = comparisonCycleId == null
          ? null
          : repository.aggregateForCycle(comparisonCycleId);
      final selectedAggregate = selectedFuture == null
          ? null
          : await selectedFuture;
      final comparisonAggregate = comparisonFuture == null
          ? null
          : await comparisonFuture;
      if (!_current(generation)) return;

      var comparisonCompatible = true;
      if (selectedCycleId != null &&
          comparisonCycleId != null &&
          repository is CycleSnapshotRepository) {
        final snapshots = repository as CycleSnapshotRepository;
        final selectedCycle = cycles.firstWhere(
          (cycle) => cycle.id == selectedCycleId,
        );
        final comparisonCycle = cycles.firstWhere(
          (cycle) => cycle.id == comparisonCycleId,
        );
        final selectedSnapshot =
            await snapshots.getCycleSet(selectedCycleId) ??
            await repository.getSet(selectedCycle.trainingSetId);
        final comparisonSnapshot =
            await snapshots.getCycleSet(comparisonCycleId) ??
            await repository.getSet(comparisonCycle.trainingSetId);
        final selectedPolicy =
            await snapshots.getCyclePolicy(selectedCycleId) ?? 'allMoves';
        final comparisonPolicy =
            await snapshots.getCyclePolicy(comparisonCycleId) ?? 'allMoves';
        comparisonCompatible =
            selectedSnapshot != null &&
            comparisonSnapshot != null &&
            selectedPolicy == comparisonPolicy &&
            _sameCycleSelection(selectedSnapshot, comparisonSnapshot);
      }
      if (!_current(generation)) return;

      final selectedSummary = selectedAggregate == null
          ? null
          : ProgressCalculator.calculate(selectedAggregate);
      final comparison =
          !comparisonCompatible ||
              selectedAggregate == null ||
              comparisonAggregate == null
          ? null
          : ProgressCalculator.compare(comparisonAggregate, selectedAggregate);
      _set(
        ProgressReportState(
          status: ProgressReportStatus.ready,
          cycles: List.unmodifiable(cycles),
          selectedCycleId: selectedCycleId,
          comparisonCycleId: comparisonCycleId,
          selectedSummary: selectedSummary,
          comparison: comparison,
          comparisonCompatible: comparisonCompatible,
        ),
      );
    } catch (_) {
      if (_current(generation)) _fail();
    }
  }

  void _fail() => _set(
    ProgressReportState(
      status: ProgressReportStatus.failed,
      cycles: _state.cycles,
      selectedCycleId: _state.selectedCycleId,
      comparisonCycleId: _state.comparisonCycleId,
      errorMessage: 'Could not load training progress. Retry the report.',
    ),
  );

  bool _current(int generation) => !_disposed && generation == _generation;

  bool _sameCycleSelection(TrainingSet left, TrainingSet right) {
    final leftItems = left.items;
    final rightItems = right.items;
    if (leftItems.length != rightItems.length) return false;
    for (var index = 0; index < leftItems.length; index++) {
      if (leftItems[index].blockId != rightItems[index].blockId ||
          leftItems[index].contentType != rightItems[index].contentType) {
        return false;
      }
    }
    return true;
  }

  void _set(ProgressReportState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
