import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart' as chessground;
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/training/puzzle_evaluator.dart';
import '../../../shared/presentation/study_board_frame.dart';
import '../application/analysis_controller.dart';

export '../../../domain/analysis/analysis_engine.dart'
    show AnalysisEngineFactory;

/// Optional, local engine assistance for one visible chess position.
///
/// Analysis begins only after the learner enables the engine. Scores always
/// describe White's perspective, regardless of whose turn it is.
final class AnalysisPanel extends StatefulWidget {
  const AnalysisPanel({
    required this.startingFen,
    required this.moves,
    this.engineFactory,
    this.onExploreSuggestion,
    this.enabled = true,
    this.compact = false,
    super.key,
  });

  final String startingFen;

  /// UCI history played from [startingFen] to this panel's current position.
  final List<String> moves;

  /// When omitted, the control can be enabled but reports the engine as
  /// unavailable. This keeps manual exploration usable without a native engine.
  final AnalysisEngineFactory? engineFactory;

  /// Adds the entire engine line to exploration after an explicit request.
  ///
  /// Merely viewing or stepping through the line never invokes this callback.
  final ValueChanged<List<String>>? onExploreSuggestion;

  /// Parent eligibility gate. Disabling it immediately stops and clears search.
  final bool enabled;

  /// Renders a small summary and moves secondary engine controls out of view.
  final bool compact;

  @override
  AnalysisPanelState createState() => AnalysisPanelState();
}

/// Public state lets owning routes stop native work before leaving a position.
final class AnalysisPanelState extends State<AnalysisPanel>
    with WidgetsBindingObserver {
  AnalysisController? _controller;
  bool _engineRequested = false;
  bool _showSuggestion = false;
  bool _linePreviewOpen = false;
  NavigatorState? _linePreviewNavigator;
  ModalRoute<dynamic>? _linePreviewRoute;
  int _linePreviewGeneration = 0;
  int _selectedLinePly = 0;
  bool _appActive = true;
  bool _preparingToLeave = false;
  bool _leaveRequested = false;
  String? _localMessage;
  int _engineIntentGeneration = 0;

  AnalysisStatus get _status =>
      _controller?.status ??
      (_engineRequested ? AnalysisStatus.unavailable : AnalysisStatus.off);
  AnalysisResult? get _result => _controller?.result;
  String? get _message => _controller?.message ?? _localMessage;

  /// Whether this panel has an active user request for engine analysis.
  ///
  /// Owners can capture this before stopping the source panel and use it to
  /// explain the engine's state when a new workspace opens. It never starts an
  /// engine by itself.
  bool get engineRequested => _engineRequested;
  bool get _hasPosition {
    if (widget.startingFen.trim().isEmpty) return false;
    try {
      chess.Chess.fromSetup(chess.Setup.parseFen(widget.startingFen));
      return true;
    } on Object {
      return false;
    }
  }

  bool get _canEnable => widget.enabled && _hasPosition && !_leaveRequested;

  void _invalidateEngineIntent() => _engineIntentGeneration++;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appActive = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant AnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final positionChanged =
        oldWidget.startingFen != widget.startingFen ||
        !listEquals(oldWidget.moves, widget.moves);
    if (positionChanged) {
      _invalidateEngineIntent();
      _dismissLinePreview();
      _selectedLinePly = 0;
      if (_hasPosition) {
        _controller?.updatePosition(
          startingFen: widget.startingFen,
          moves: widget.moves,
        );
      } else {
        _engineRequested = false;
        _showSuggestion = false;
        _localMessage = null;
        final controller = _controller;
        if (controller != null && controller.isEnabled) {
          unawaited(_disable(controller));
        }
      }
    }
    if (oldWidget.enabled && !widget.enabled) {
      _invalidateEngineIntent();
      _engineRequested = false;
      _showSuggestion = false;
      _selectedLinePly = 0;
      _dismissLinePreview();
      _localMessage = null;
      final controller = _controller;
      if (controller != null) unawaited(_disable(controller));
    }
    if (oldWidget.engineFactory != widget.engineFactory &&
        _engineRequested &&
        widget.enabled) {
      _invalidateEngineIntent();
      final oldController = _controller;
      oldController?.removeListener(_controllerChanged);
      _controller = null;
      _dismissLinePreview();
      if (oldController != null) unawaited(_disposeController(oldController));
      if (widget.engineFactory == null) {
        _localMessage = 'Local analysis is unavailable on this device.';
      } else {
        _localMessage = null;
        final controller = _createController();
        controller.updatePosition(
          startingFen: widget.startingFen,
          moves: widget.moves,
        );
        unawaited(_enable(controller));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _appActive = active;
    if (active) {
      // Foregrounding never resumes native analysis automatically.
      if (mounted) setState(() {});
      return;
    }
    _invalidateEngineIntent();
    final controller = _controller;
    if (controller != null && controller.isEnabled && !controller.isPaused) {
      unawaited(_pause(controller));
    } else if (mounted) {
      setState(() {});
    }
  }

  /// Stops and disposes the engine before a containing route leaves.
  Future<void> prepareToLeave() async {
    _invalidateEngineIntent();
    _leaveRequested = true;
    _dismissLinePreview();
    _preparingToLeave = true;
    if (mounted) setState(() {});
    final controller = _controller;
    try {
      if (controller != null) {
        await controller.prepareToLeave();
      }
    } finally {
      _preparingToLeave = false;
      if (mounted) setState(() {});
    }
  }

  /// Compatibility name for owners that treat route departure as a stop.
  Future<void> stopAnalysis() => prepareToLeave();

  @override
  void dispose() {
    _invalidateEngineIntent();
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_controllerChanged);
      unawaited(_disposeController(controller));
    }
    super.dispose();
  }

  AnalysisController _createController() {
    final factory = widget.engineFactory!;
    final controller = AnalysisController(engineFactory: factory);
    controller.addListener(_controllerChanged);
    _controller = controller;
    return controller;
  }

  void _controllerChanged() {
    if (!mounted) return;
    if (_controller?.result == null) _dismissLinePreview();
    if (_controller?.result == null) _selectedLinePly = 0;
    setState(() {});
  }

  Future<void> _setEngineRequested(bool requested) async {
    if ((!_canEnable || !_appActive || _preparingToLeave) && requested) {
      return;
    }
    if (!requested) {
      _invalidateEngineIntent();
      _engineRequested = false;
      _showSuggestion = false;
      _selectedLinePly = 0;
      _dismissLinePreview();
      _localMessage = null;
      if (mounted) setState(() {});
      final controller = _controller;
      if (controller != null) await _disable(controller);
      return;
    }

    _invalidateEngineIntent();
    _engineRequested = true;
    _localMessage = null;
    if (mounted) setState(() {});
    final factory = widget.engineFactory;
    if (factory == null) {
      _localMessage = 'Local analysis is unavailable on this device.';
      if (mounted) setState(() {});
      return;
    }
    final controller = _controller ?? _createController();
    controller.updatePosition(
      startingFen: widget.startingFen,
      moves: widget.moves,
    );
    await _enable(controller);
  }

  Future<void> _enable(AnalysisController controller) async {
    try {
      await controller.setEnabled(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _localMessage = _friendlyMessage(error);
      });
    }
  }

  Future<void> _disable(AnalysisController controller) async {
    try {
      await controller.setEnabled(false);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _localMessage = _friendlyMessage(error);
      });
    }
  }

  Future<void> _pause(AnalysisController controller) async {
    _dismissLinePreview();
    try {
      await controller.pause();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _localMessage = _friendlyMessage(error);
      });
    }
  }

  Future<void> _retryEngine() async {
    if (!_canEnable || !_appActive || _preparingToLeave || !_engineRequested) {
      return;
    }
    final factory = widget.engineFactory;
    if (factory == null) {
      setState(() {
        _localMessage = 'Local analysis is unavailable on this device.';
      });
      return;
    }
    final controller = _controller ?? _createController();
    final intentGeneration = _engineIntentGeneration;
    _dismissLinePreview();
    _localMessage = null;
    if (mounted) setState(() {});
    try {
      if (controller.isEnabled) await controller.setEnabled(false);
      if (!_isCurrentRetry(intentGeneration, controller)) return;
      controller.updatePosition(
        startingFen: widget.startingFen,
        moves: widget.moves,
      );
      await controller.setEnabled(true);
      if (!_isCurrentRetry(intentGeneration, controller)) return;
    } on Object catch (error) {
      if (!_isCurrentRetry(intentGeneration, controller)) return;
      setState(() {
        _localMessage = _friendlyMessage(error);
      });
    }
  }

  bool _isCurrentRetry(int intentGeneration, AnalysisController controller) =>
      mounted &&
      identical(_controller, controller) &&
      _engineRequested &&
      _canEnable &&
      _appActive &&
      !_preparingToLeave &&
      intentGeneration == _engineIntentGeneration;

  Future<void> _resumeEngine() async {
    final controller = _controller;
    if (!_canEnable || !_appActive || _preparingToLeave || controller == null) {
      return;
    }
    controller.resume();
  }

  void _analyzeDeeper() {
    _dismissLinePreview();
    _controller?.analyzeDeeper();
    if (mounted) setState(() {});
  }

  void _openLinePreview(List<_EngineLinePly> line, {int initialPly = 0}) {
    if (_preparingToLeave || line.isEmpty) return;
    setState(() {
      _showSuggestion = true;
      _selectedLinePly = initialPly.clamp(0, line.length).toInt();
    });
    _linePreviewOpen = true;
    final startingFen = widget.startingFen;
    final moves = List<String>.unmodifiable(widget.moves);
    final intentGeneration = _engineIntentGeneration;
    final previewGeneration = ++_linePreviewGeneration;
    unawaited(
      showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) {
          _linePreviewNavigator = Navigator.of(sheetContext);
          _linePreviewRoute = ModalRoute.of(sheetContext);
          return _EngineLinePreviewSheet(
            line: line,
            initialPly: initialPly,
            onPlySelected: (ply) {
              if (mounted) setState(() => _selectedLinePly = ply);
            },
            canAddLine: widget.onExploreSuggestion != null,
          );
        },
      ).then((lineToAdd) {
        if (previewGeneration != _linePreviewGeneration) return;
        _linePreviewOpen = false;
        _linePreviewNavigator = null;
        _linePreviewRoute = null;
        if (lineToAdd == null ||
            !mounted ||
            !_engineRequested ||
            !widget.enabled ||
            _preparingToLeave ||
            intentGeneration != _engineIntentGeneration ||
            startingFen != widget.startingFen ||
            !listEquals(moves, widget.moves)) {
          return;
        }
        widget.onExploreSuggestion?.call(lineToAdd);
      }),
    );
  }

  void _dismissLinePreview() {
    if (!_linePreviewOpen) return;
    _linePreviewOpen = false;
    _linePreviewGeneration++;
    final navigator = _linePreviewNavigator;
    final route = _linePreviewRoute;
    _linePreviewNavigator = null;
    _linePreviewRoute = null;
    if (navigator != null && route != null) {
      void removePreviewRoute() {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      }

      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
        removePreviewRoute();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          removePreviewRoute();
        });
      }
    }
  }

  List<_EngineLinePly>? _engineLineFor(AnalysisResult result) {
    try {
      var position = chess.Chess.fromSetup(
        chess.Setup.parseFen(widget.startingFen),
      );
      for (final uci in widget.moves) {
        final move = chess.Move.parse(uci);
        if (move == null || !position.isLegal(move)) return null;
        position = position.play(move) as chess.Chess;
      }

      final line = <_EngineLinePly>[];
      for (final uci in result.principalVariation) {
        final move = chess.Move.parse(uci);
        if (move == null || !position.isLegal(move)) return null;
        final before = position;
        final san = position.makeSan(move).$2;
        final number = position.fullmoves;
        final prefix = position.turn == chess.Side.white
            ? '$number.'
            : '$number...';
        position = position.play(move) as chess.Chess;
        line.add(
          _EngineLinePly(
            uci: uci,
            san: san,
            notation: '$prefix $san',
            positionBefore: before,
            position: position,
            move: move,
          ),
        );
      }
      return List.unmodifiable(line);
    } on Object {
      return null;
    }
  }

  String get _statusText {
    if (!_hasPosition) return 'No position available for analysis.';
    if (!widget.enabled) return 'Analysis is unavailable in this mode.';
    return switch (_status) {
      AnalysisStatus.off => 'Analysis is off.',
      AnalysisStatus.analyzing => 'Analyzing position…',
      AnalysisStatus.ready => 'Analysis ready.',
      AnalysisStatus.paused => 'Analysis paused.',
      AnalysisStatus.unavailable => 'Engine unavailable.',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPosition) return const SizedBox.shrink();
    final result = _result;
    final candidateLine = result == null
        ? const <_EngineLinePly>[]
        : _engineLineFor(result);
    final lineUnavailable = candidateLine == null;
    final line = candidateLine ?? const <_EngineLinePly>[];
    final hasSuggestion = line.isNotEmpty;
    final canToggle = _canEnable && _appActive && !_preparingToLeave;
    final controller = _controller;
    if (widget.compact) {
      return _compactPanel(
        context,
        result: result,
        line: line,
        hasSuggestion: hasSuggestion,
        lineUnavailable: lineUnavailable,
        canToggle: canToggle,
        controller: controller,
      );
    }
    if (_status == AnalysisStatus.off &&
        !_engineRequested &&
        _localMessage == null) {
      return _engineSwitch(canToggle: canToggle, compact: true);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _engineSwitch(canToggle: canToggle),
            _statusRow(context),
            if (_message case final message? when message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              _evaluationSummary(context, result),
            ],
            if (lineUnavailable)
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  'Engine line unavailable.',
                  key: ValueKey<String>('engine-line-unavailable'),
                ),
              ),
            if (hasSuggestion) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      key: const ValueKey<String>('view-engine-line'),
                      onPressed: _preparingToLeave
                          ? null
                          : () => _openLinePreview(line),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View engine line'),
                    ),
                    if (_showSuggestion)
                      TextButton(
                        key: const ValueKey<String>('hide-engine-line'),
                        onPressed: _preparingToLeave
                            ? null
                            : () => setState(() {
                                _showSuggestion = false;
                                _selectedLinePly = 0;
                              }),
                        child: const Text('Hide suggestions'),
                      ),
                  ],
                ),
              ),
              if (_showSuggestion) ...[
                const SizedBox(height: 2),
                _EngineLineChips(
                  line: line,
                  selectedPly: _selectedLinePly,
                  keyPrefix: 'engine-line-move',
                  onSelect: (ply) => _openLinePreview(line, initialPly: ply),
                ),
              ],
            ],
            const SizedBox(height: 4),
            _engineControls(controller),
          ],
        ),
      ),
    );
  }

  Widget _engineSwitch({required bool canToggle, bool compact = false}) =>
      Semantics(
        label: 'Local engine analysis',
        value: _engineRequested ? 'On' : 'Off',
        child: SwitchListTile.adaptive(
          dense: compact,
          visualDensity: compact
              ? VisualDensity.compact
              : VisualDensity.standard,
          minVerticalPadding: 0,
          minTileHeight: compact ? 48 : null,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Engine: ${_engineRequested ? 'On' : 'Off'}',
            maxLines: compact ? 1 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
          ),
          value: _engineRequested,
          onChanged: canToggle
              ? (value) => unawaited(_setEngineRequested(value))
              : null,
        ),
      );

  Widget _compactPanel(
    BuildContext context, {
    required AnalysisResult? result,
    required List<_EngineLinePly> line,
    required bool hasSuggestion,
    required bool lineUnavailable,
    required bool canToggle,
    required AnalysisController? controller,
  }) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final side = _sideToMove;
    final sideName = side == chess.Side.white ? 'White' : 'Black';
    final score = result == null
        ? _statusText
        : '${result.mate == null ? 'White ' : ''}'
              '${_formatEvaluation(result)} · $sideName to move';
    final items = _compactMenuItems(controller);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 240;
        final largeText = scale > 1.5;
        final topRowHeight = largeText ? 64.0 : 48.0;
        return SizedBox(
          key: const ValueKey<String>('compact-analysis-row'),
          height: narrow ? topRowHeight + 48 : topRowHeight,
          child: narrow
              ? Column(
                  children: [
                    SizedBox(
                      height: topRowHeight,
                      child: Row(
                        children: [
                          _compactEngineSwitch(canToggle),
                          Expanded(
                            child: _compactScore(
                              score: score,
                              result: result,
                              sideName: sideName,
                              largeText: largeText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (lineUnavailable)
                            const Tooltip(
                              message: 'Engine line unavailable.',
                              child: Icon(Icons.info_outline),
                            )
                          else if (hasSuggestion)
                            _viewLineButton(line),
                          if (items.isNotEmpty)
                            _compactControlsMenu(items, controller),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    if (constraints.maxWidth >= 290 && !largeText)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 4),
                        child: Text(
                          'Engine',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    _compactEngineSwitch(canToggle),
                    Expanded(
                      child: _compactScore(
                        score: score,
                        result: result,
                        sideName: sideName,
                        largeText: largeText,
                      ),
                    ),
                    if (lineUnavailable)
                      const Tooltip(
                        message: 'Engine line unavailable.',
                        child: Icon(Icons.info_outline),
                      )
                    else if (hasSuggestion)
                      _viewLineButton(line),
                    if (items.isNotEmpty)
                      _compactControlsMenu(items, controller),
                  ],
                ),
        );
      },
    );
  }

  Widget _compactEngineSwitch(bool canToggle) => Tooltip(
    message: 'Local engine analysis',
    child: Semantics(
      label: 'Local engine analysis',
      value: _engineRequested ? 'On' : 'Off',
      child: Switch.adaptive(
        value: _engineRequested,
        onChanged: canToggle
            ? (value) => unawaited(_setEngineRequested(value))
            : null,
      ),
    ),
  );

  Widget _compactScore({
    required String score,
    required AnalysisResult? result,
    required String sideName,
    required bool largeText,
  }) => Tooltip(
    message: result == null
        ? (_message ?? score)
        : '$score. Depth ${result.depth}. Evaluation is from White’s perspective.',
    child: result == null
        ? Text(
            score,
            key: const ValueKey<String>('analysis-status'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                largeText
                    ? '${result.mate == null ? 'White ' : ''}${_formatEvaluation(result)}'
                    : score,
                key: const ValueKey<String>('analysis-evaluation'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
                semanticsLabel:
                    'Evaluation from White’s perspective; $sideName to move',
              ),
              Text(
                largeText ? '$sideName to move' : 'Depth ${result.depth}',
                key: largeText
                    ? null
                    : const ValueKey<String>('analysis-depth'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: largeText
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
  );

  Widget _viewLineButton(List<_EngineLinePly> line) => IconButton(
    key: const ValueKey<String>('view-engine-line'),
    tooltip: 'View engine line',
    onPressed: _preparingToLeave ? null : () => _openLinePreview(line),
    icon: Icon(_showSuggestion ? Icons.visibility : Icons.visibility_outlined),
  );

  Widget _compactControlsMenu(
    List<PopupMenuEntry<String>> items,
    AnalysisController? controller,
  ) => PopupMenuButton<String>(
    key: const ValueKey<String>('engine-controls-menu'),
    tooltip: 'Engine controls',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) {
      switch (action) {
        case 'pause':
          if (controller != null) unawaited(_pause(controller));
          break;
        case 'resume':
          unawaited(_resumeEngine());
          break;
        case 'deeper':
          _analyzeDeeper();
          break;
        case 'retry':
          unawaited(_retryEngine());
          break;
        case 'hide':
          setState(() {
            _showSuggestion = false;
            _selectedLinePly = 0;
          });
          break;
      }
    },
    itemBuilder: (context) => items,
  );

  List<PopupMenuEntry<String>> _compactMenuItems(
    AnalysisController? controller,
  ) {
    final entries = <PopupMenuEntry<String>>[];
    if (_status == AnalysisStatus.paused && _engineRequested) {
      entries.add(
        const PopupMenuItem(value: 'resume', child: Text('Resume analysis')),
      );
    }
    if ((_status == AnalysisStatus.ready ||
            _status == AnalysisStatus.analyzing) &&
        _engineRequested &&
        controller != null) {
      entries.add(
        const PopupMenuItem(value: 'pause', child: Text('Pause analysis')),
      );
    }
    if (_status == AnalysisStatus.ready && _engineRequested) {
      entries.add(
        const PopupMenuItem(value: 'deeper', child: Text('Analyze deeper')),
      );
    }
    if (_status == AnalysisStatus.unavailable && _engineRequested) {
      entries.add(
        const PopupMenuItem(value: 'retry', child: Text('Retry engine')),
      );
    }
    if (_showSuggestion) {
      entries.add(
        const PopupMenuItem(value: 'hide', child: Text('Hide suggestions')),
      );
    }
    return entries;
  }

  Widget _statusRow(BuildContext context) => Row(
    children: [
      if (_status == AnalysisStatus.analyzing)
        const Padding(
          padding: EdgeInsetsDirectional.only(end: 8),
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      Expanded(
        child: Text(
          _statusText,
          key: const ValueKey<String>('analysis-status'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );

  Widget _evaluationSummary(BuildContext context, AnalysisResult result) {
    final sideToMove = _sideToMove;
    final evaluation =
        '${result.mate == null ? 'White ' : ''}${_formatEvaluation(result)}';
    final summary =
        '$evaluation · '
        '${sideToMove == chess.Side.white ? 'White' : 'Black'} to move';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              'Evaluation from White’s perspective; '
              '${sideToMove == chess.Side.white ? 'White' : 'Black'} to move',
          child: Text(
            summary,
            key: const ValueKey<String>('analysis-evaluation'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Text(
          'Depth ${result.depth}',
          key: const ValueKey<String>('analysis-depth'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  chess.Side get _sideToMove {
    try {
      var position = chess.Chess.fromSetup(
        chess.Setup.parseFen(widget.startingFen),
      );
      for (final uci in widget.moves) {
        final move = chess.Move.parse(uci);
        if (move == null || !position.isLegal(move)) return position.turn;
        position = position.play(move) as chess.Chess;
      }
      return position.turn;
    } on Object {
      return chess.Side.white;
    }
  }

  Widget _engineControls(AnalysisController? controller) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      if (_status == AnalysisStatus.paused &&
          _engineRequested &&
          controller != null)
        OutlinedButton.icon(
          onPressed: _canEnable && _appActive && !_preparingToLeave
              ? () => unawaited(_resumeEngine())
              : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume analysis'),
        ),
      if ((_status == AnalysisStatus.ready ||
              _status == AnalysisStatus.analyzing) &&
          _engineRequested &&
          controller != null)
        OutlinedButton.icon(
          onPressed: _preparingToLeave
              ? null
              : () => unawaited(_pause(controller)),
          icon: const Icon(Icons.pause),
          label: const Text('Pause analysis'),
        ),
      if (_status == AnalysisStatus.ready &&
          _engineRequested &&
          controller != null)
        OutlinedButton.icon(
          key: const ValueKey<String>('analyze-deeper'),
          onPressed: _preparingToLeave ? null : _analyzeDeeper,
          icon: const Icon(Icons.manage_search),
          label: const Text('Analyze deeper'),
        ),
      if (_status == AnalysisStatus.unavailable && _engineRequested)
        OutlinedButton.icon(
          onPressed: _canEnable && !_preparingToLeave
              ? () => unawaited(_retryEngine())
              : null,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry engine'),
        ),
    ],
  );

  Future<void> _disposeController(AnalysisController controller) async {
    try {
      await controller.prepareToLeave();
    } on Object {
      // Widget disposal must not leave a detached route waiting on native work.
    }
    try {
      controller.dispose();
    } on Object {
      // Controller disposal is best-effort after the stop barrier completes.
    }
  }

  String _friendlyMessage(Object error) {
    if (error is UnsupportedError) {
      return 'Local analysis is unavailable on this device.';
    }
    return 'Engine unavailable. You can still explore moves. Retry analysis.';
  }
}

final class _EngineLinePly {
  const _EngineLinePly({
    required this.uci,
    required this.san,
    required this.notation,
    required this.positionBefore,
    required this.position,
    required this.move,
  });

  final String uci;
  final String san;
  final String notation;
  final chess.Chess positionBefore;
  final chess.Chess position;
  final chess.Move move;
}

final class _EngineLineChips extends StatelessWidget {
  const _EngineLineChips({
    required this.line,
    required this.onSelect,
    this.selectedPly = 0,
    this.keyPrefix = 'engine-line-preview-move',
  });

  final List<_EngineLinePly> line;
  final ValueChanged<int> onSelect;
  final int selectedPly;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < line.length; index++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: OutlinedButton(
                key: ValueKey<String>('$keyPrefix-${index + 1}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  backgroundColor: selectedPly == index + 1
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                ),
                onPressed: () => onSelect(index + 1),
                child: Text(line[index].notation),
              ),
            ),
        ],
      ),
    ),
  );
}

final class _EngineLinePreviewSheet extends StatefulWidget {
  const _EngineLinePreviewSheet({
    required this.line,
    required this.initialPly,
    required this.onPlySelected,
    required this.canAddLine,
  });

  final List<_EngineLinePly> line;
  final int initialPly;
  final ValueChanged<int> onPlySelected;
  final bool canAddLine;

  @override
  State<_EngineLinePreviewSheet> createState() =>
      _EngineLinePreviewSheetState();
}

final class _EngineLinePreviewSheetState
    extends State<_EngineLinePreviewSheet> {
  late int _selectedPly;

  @override
  void initState() {
    super.initState();
    _selectedPly = widget.initialPly.clamp(0, widget.line.length).toInt();
  }

  void _selectPly(int ply) {
    setState(() => _selectedPly = ply.clamp(0, widget.line.length).toInt());
    widget.onPlySelected(_selectedPly);
  }

  @override
  Widget build(BuildContext context) {
    final atOrigin = _selectedPly == 0;
    final position = atOrigin
        ? widget.line.first.positionBefore
        : widget.line[_selectedPly - 1].position;
    final lastMove = atOrigin ? null : widget.line[_selectedPly - 1].move;
    final side = position.turn == chess.Side.white
        ? PuzzleSide.white
        : PuzzleSide.black;
    final location = atOrigin
        ? 'Start of engine line'
        : 'After ${widget.line[_selectedPly - 1].notation}';
    final sideName = side == PuzzleSide.white ? 'White' : 'Black';
    final screenSize = MediaQuery.sizeOf(context);
    final maxBoardSize = math.min(320.0, screenSize.height * 0.45);
    final boardSize = (screenSize.width - 32)
        .clamp(0.0, maxBoardSize)
        .toDouble();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenSize.height * 0.92),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Engine line preview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '$location · $sideName to move',
                          key: const ValueKey<String>('engine-line-position'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _EngineLineChips(
                          line: widget.line,
                          selectedPly: _selectedPly,
                          onSelect: (ply) {
                            _selectPly(ply);
                          },
                          keyPrefix: 'engine-line-preview-move',
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: SizedBox.square(
                            dimension: boardSize,
                            child: StudyBoardFrame(
                              sideToMove: side,
                              child: Semantics(
                                container: true,
                                label:
                                    'Engine line board. $location. '
                                    '$sideName to move.',
                                child: ExcludeSemantics(
                                  child: chessground.StaticChessboard(
                                    key: const ValueKey<String>(
                                      'engine-line-board',
                                    ),
                                    size: boardSize,
                                    orientation: chess.Side.white,
                                    fen: position.fen,
                                    lastMove: lastMove,
                                    settings:
                                        const chessground.StaticChessboardSettings(
                                          enableCoordinates: true,
                                          animationDuration: Duration.zero,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _selectedPly > 0
                                ? () => _selectPly(_selectedPly - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Previous'),
                          ),
                          Text('$_selectedPly of ${widget.line.length}'),
                          TextButton.icon(
                            onPressed: _selectedPly < widget.line.length
                                ? () => _selectPly(_selectedPly + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                      if (widget.canAddLine)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop<List<String>>(
                                List.unmodifiable(
                                  widget.line.map((ply) => ply.uci),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add line to exploration'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatEvaluation(AnalysisResult result) {
  final mate = result.mate;
  if (mate != null) {
    if (mate == 0) return 'Mate now for White';
    return mate > 0 ? 'Mate in $mate for White' : 'Mate in ${-mate} for Black';
  }
  final centipawns = result.centipawns;
  if (centipawns == null) return 'Unavailable';
  final value = (centipawns.abs() / 100).toStringAsFixed(2);
  if (centipawns > 0) return '+$value';
  if (centipawns < 0) return '−$value';
  return '0.00';
}
