import 'dart:async';

import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/analysis/analysis_engine.dart';
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
    super.key,
  });

  final String startingFen;

  /// UCI history played from [startingFen] to this panel's current position.
  final List<String> moves;

  /// When omitted, the control can be enabled but reports the engine as
  /// unavailable. This keeps manual exploration usable without a native engine.
  final AnalysisEngineFactory? engineFactory;

  /// Called only after the learner explicitly asks to explore the shown line.
  final ValueChanged<List<String>>? onExploreSuggestion;

  /// Parent eligibility gate. Disabling it immediately stops and clears search.
  final bool enabled;

  @override
  AnalysisPanelState createState() => AnalysisPanelState();
}

/// Public state lets owning routes stop native work before leaving a position.
final class AnalysisPanelState extends State<AnalysisPanel>
    with WidgetsBindingObserver {
  AnalysisController? _controller;
  bool _engineRequested = false;
  bool _showSuggestion = false;
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
      _showSuggestion = false;
      if (_hasPosition) {
        _controller?.updatePosition(
          startingFen: widget.startingFen,
          moves: widget.moves,
        );
      } else {
        _engineRequested = false;
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
      _showSuggestion = false;
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
    _showSuggestion = false;
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
    _showSuggestion = false;
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
    if (_controller?.result == null) _showSuggestion = false;
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
      _localMessage = null;
      if (mounted) setState(() {});
      final controller = _controller;
      if (controller != null) await _disable(controller);
      return;
    }

    _invalidateEngineIntent();
    _engineRequested = true;
    _showSuggestion = false;
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
    _showSuggestion = false;
    if (mounted) setState(() {});
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
    _showSuggestion = false;
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
    _showSuggestion = false;
    _controller?.analyzeDeeper();
    if (mounted) setState(() {});
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
    final hasSuggestion =
        result != null && result.principalVariation.isNotEmpty;
    final canToggle = _canEnable && _appActive && !_preparingToLeave;
    final controller = _controller;
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
            Row(
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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (_message case final message? when message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Evaluation from White’s perspective',
                child: Text(
                  'Evaluation (White): ${_formatEvaluation(result)}',
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
            if (hasSuggestion) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _preparingToLeave
                      ? null
                      : () =>
                            setState(() => _showSuggestion = !_showSuggestion),
                  icon: Icon(
                    _showSuggestion ? Icons.visibility_off : Icons.lightbulb,
                  ),
                  label: Text(
                    _showSuggestion ? 'Hide suggestion' : 'Show suggestion',
                  ),
                ),
              ),
              if (_showSuggestion) ...[
                const SizedBox(height: 4),
                Text(
                  'Suggested line: ${result.principalVariation.join(' ')}',
                  key: const ValueKey<String>('analysis-suggestion'),
                  softWrap: true,
                ),
                if (widget.onExploreSuggestion != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      onPressed: _preparingToLeave
                          ? null
                          : () => widget.onExploreSuggestion!(
                              List.unmodifiable(result.principalVariation),
                            ),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explore suggestion'),
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 4),
            Wrap(
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
            ),
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
