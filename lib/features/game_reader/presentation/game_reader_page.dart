import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/analysis/analysis_engine.dart';
import '../../../domain/analysis/exploration_repository.dart';
import '../../../domain/chess_content/chess_content.dart';
import '../../../domain/chess_content/content_type.dart';
import '../../../shared/presentation/study_block_navigation.dart';
import 'text_view.dart';
import '../../../shared/presentation/study_mode.dart';

/// Builds the separately implemented puzzle-solving experience.
typedef PuzzleViewBuilder = Widget Function(
  BuildContext context,
  ChessContent puzzle,
  ValueChanged<StudyMode> onModeChanged,
);

/// Selects the reader presentation appropriate for one parsed PGN block.
final class GameReaderPage extends StatefulWidget {
  const GameReaderPage({
    required this.content,
    this.puzzleViewBuilder,
    this.onClassificationOverride,
    this.showBlockNavigation = false,
    this.bookName,
    this.section,
    this.blockNumber,
    this.unavailableMessage,
    this.onRetryContent,
    this.initialReaderState,
    this.onSaveReaderState,
    this.onNextBlock,
    this.onPreviousBlock,
    this.onBookSettings,
    this.explorationScopeId,
    this.explorationRepository,
    this.analysisEngineFactory,
    this.isNestedExploring,
    this.onReturnFromExploration,
    this.onPrepareToLeave,
    super.key,
  });

  final ChessContent content;
  final String? bookName;
  final String? section;
  final int? blockNumber;
  final String? unavailableMessage;
  final VoidCallback? onRetryContent;
  final Map<String, dynamic>? initialReaderState;
  final Future<void> Function(Map<String, dynamic>)? onSaveReaderState;
  final bool showBlockNavigation;
  final VoidCallback? onNextBlock;
  final VoidCallback? onPreviousBlock;
  final VoidCallback? onBookSettings;
  final String? explorationScopeId;
  final ExplorationRepository? explorationRepository;
  final AnalysisEngineFactory? analysisEngineFactory;
  final bool Function()? isNestedExploring;
  final Future<void> Function()? onReturnFromExploration;
  final Future<void> Function()? onPrepareToLeave;

  /// Injected puzzle presentation; no solution-bearing content is rendered
  /// when a puzzle view has not been supplied by the caller.
  final PuzzleViewBuilder? puzzleViewBuilder;

  final Future<void> Function(ContentType)? onClassificationOverride;

  @override
  GameReaderPageState createState() => GameReaderPageState();
}

/// Page state exposed for parent flows that must save reader work before exit.
final class GameReaderPageState extends State<GameReaderPage> {
  late ChessContent content = widget.content;
  StudyMode? _puzzleMode;
  bool _saving = false;
  bool _allowPop = false;
  late Map<String, dynamic> _readerState = widget.initialReaderState ?? {};
  Timer? _readerSaveTimer;
  Future<void> _readerWrite = Future<void>.value();
  Future<void>? _activePrepare;
  Future<void>? _activeExplorationReturn;
  final GlobalKey<TextViewState> _textViewKey = GlobalKey<TextViewState>();

  bool get isExploring =>
      (_textViewKey.currentState?.isExploring ?? false) ||
      (widget.isNestedExploring?.call() ?? false);

  /// Persist an open exploration and the authored reader cursor before a
  /// parent replaces this page.
  Future<void> prepareToLeave() {
    final active = _activePrepare;
    if (active != null) return active;
    final operation = _prepareToLeave();
    _activePrepare = operation;
    return operation.whenComplete(() {
      if (identical(_activePrepare, operation)) _activePrepare = null;
    });
  }

  Future<void> _prepareToLeave() async {
    final wasSaving = _saving;
    if (!wasSaving && mounted) setState(() => _saving = true);
    try {
      await _textViewKey.currentState?.prepareToLeave();
      await widget.onPrepareToLeave?.call();
      await _flushReader();
    } finally {
      if (!wasSaving && mounted) setState(() => _saving = false);
    }
  }

  /// Return from an open exploration to authored reading, preserving its
  /// cursor and scroll, and save the restored reader state.
  Future<void> returnFromExploration() {
    final active = _activeExplorationReturn;
    if (active != null) return active;
    final operation = _returnFromExploration();
    _activeExplorationReturn = operation;
    return operation.whenComplete(() {
      if (identical(_activeExplorationReturn, operation)) {
        _activeExplorationReturn = null;
      }
    });
  }

  Future<void> _returnFromExploration() async {
    final textView = _textViewKey.currentState;
    if (textView?.isExploring == true) {
      await textView!.returnFromExploration();
    } else if (widget.isNestedExploring?.call() ?? false) {
      await widget.onReturnFromExploration?.call();
    } else {
      return;
    }
    await _flushReader();
  }

  @override
  void initState() {
    super.initState();
    if (content.contentType == ContentType.puzzle &&
        widget.puzzleViewBuilder != null) {
      _puzzleMode = StudyMode.reading;
    }
  }

  void _setPuzzleMode(StudyMode mode) {
    if (!mounted || _puzzleMode == mode) return;
    setState(() => _puzzleMode = mode);
  }

  void _readerChanged(Map<String, dynamic> value) {
    _readerState = value;
    _readerSaveTimer?.cancel();
    _readerSaveTimer = Timer(const Duration(milliseconds: 150), () {
      final snapshot = Map<String, dynamic>.from(_readerState);
      _readerWrite = _readerWrite.catchError((Object _) {}).then((_) async {
        await widget.onSaveReaderState?.call(snapshot);
      });
      _readerWrite.catchError((Object _) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reading position could not be saved. Retry before leaving.',
              ),
            ),
          );
        }
      });
    });
  }

  Future<void> _flushReader() async {
    _readerSaveTimer?.cancel();
    try {
      await _readerWrite;
    } catch (_) {
      /* Retry the latest cursor. */
    }
    await widget.onSaveReaderState?.call(_readerState);
  }

  Future<void> _navigateBlock(VoidCallback action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await prepareToLeave();
      if (mounted) action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reading position could not be saved. Retry before leaving.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _returnToBook() async {
    if (_saving) return;
    if (isExploring) {
      try {
        await returnFromExploration();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Exploration could not be saved. Retry before returning.',
              ),
            ),
          );
        }
      }
      return;
    }
    await _navigateBlock(() {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _readerSaveTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      content = widget.content;
      _puzzleMode =
          content.contentType == ContentType.puzzle &&
              widget.puzzleViewBuilder != null
          ? StudyMode.reading
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? meaningfulHeader(String name) {
      final value = content.headers[name]?.trim();
      return value == null || value.isEmpty || value == '?' ? null : value;
    }

    final white = meaningfulHeader('White');
    final black = meaningfulHeader('Black');
    final studyTitle =
        meaningfulHeader('X-Title') ??
        meaningfulHeader('Event') ??
        (white != null && black != null ? '$white vs $black' : null) ??
        (content.rootMoves.isNotEmpty ? 'Game' : 'Study text');
    final title =
        widget.bookName ??
        switch (content.contentType) {
          ContentType.puzzle => 'Puzzle',
          ContentType.unsupported => 'Unsupported content',
          ContentType.text => studyTitle,
        };
    final titleStyle = Theme.of(context).textTheme.headlineSmall!;
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width - 32);
    final titleHeight = widget.bookName == null
        ? titlePainter.height + 24
        : 48 * MediaQuery.textScalerOf(context).scale(1.0);
    titlePainter.dispose();
    final surface = Scaffold(
      appBar: AppBar(
        centerTitle: false,
        scrolledUnderElevation: 0,
        toolbarHeight: widget.bookName == null
            ? null
            : 44 + 20 * MediaQuery.textScalerOf(context).scale(1.0),
        title: widget.bookName == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.bookName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_puzzleMode case final mode?)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 8),
                          child: Semantics(
                            label: mode == StudyMode.reading
                                ? mode.label
                                : 'Casual practice, ${mode.label}',
                            excludeSemantics: true,
                            child: Text(
                              mode.label,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    [
                      if (widget.section?.trim().isNotEmpty == true)
                        widget.section!,
                      'Block ${widget.blockNumber}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
        bottom: widget.bookName != null
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(titleHeight),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: widget.bookName == null
                              ? titleStyle
                              : Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.blockNumber != null)
                          Text(
                            [
                              if (widget.section?.trim().isNotEmpty == true)
                                widget.section!,
                              'Block ${widget.blockNumber}',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        actions: [
          if (widget.onBookSettings != null &&
              content.contentType == ContentType.puzzle)
            IconButton(
              tooltip: 'Book settings',
              onPressed: _saving ? null : widget.onBookSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          if (widget.onClassificationOverride != null)
            PopupMenuButton<ContentType>(
              tooltip: 'Change content type',
              enabled: !_saving,
              onSelected: _override,
              itemBuilder: (_) => [
                for (final type in const [ContentType.text, ContentType.puzzle])
                  CheckedPopupMenuItem(
                    value: type,
                    checked: content.contentType == type,
                    child: Text(
                      type == ContentType.text ? 'Study text / game' : 'Puzzle',
                    ),
                  ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      bottomNavigationBar:
          widget.showBlockNavigation &&
              (widget.unavailableMessage != null ||
                  content.contentType != ContentType.puzzle ||
                  widget.puzzleViewBuilder == null)
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    StudyPreviousBlockButton(
                      showLabel: true,
                      onPressed: _saving || widget.onPreviousBlock == null
                          ? null
                          : () => _navigateBlock(widget.onPreviousBlock!),
                    ),
                    StudyNextBlockButton(
                      label: widget.onNextBlock == null
                          ? 'Back to book'
                          : 'Next block',
                      onPressed: _saving
                          ? null
                          : widget.onNextBlock == null
                          ? _returnToBook
                          : () => _navigateBlock(widget.onNextBlock!),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: widget.unavailableMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.unavailableMessage!),
                    TextButton(
                      onPressed: widget.onRetryContent,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : switch (content.contentType) {
              ContentType.text => TextView(
                key: _textViewKey,
                content: content,
                initialState: widget.initialReaderState,
                explorationScopeId: widget.explorationScopeId,
                explorationRepository: widget.explorationRepository,
                analysisEngineFactory: widget.analysisEngineFactory,
                onStateChanged: widget.onSaveReaderState == null
                    ? null
                    : _readerChanged,
              ),
              ContentType.puzzle =>
                widget.puzzleViewBuilder?.call(
                      context,
                      content,
                      _setPuzzleMode,
                    ) ??
                    const _UnavailableMode(
                      message: 'Puzzle practice is not available yet.',
                    ),
              ContentType.unsupported => const _UnavailableMode(
                message: 'This content type is not supported for display.',
              ),
            },
    );
    final guardedSurface = IgnorePointer(ignoring: _saving, child: surface);
    if (widget.onSaveReaderState == null ||
        content.contentType == ContentType.puzzle) {
      return guardedSurface;
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (isExploring) {
            final messenger = ScaffoldMessenger.of(context);
            unawaited(
              returnFromExploration().catchError((Object _) {
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exploration could not be saved. Retry before leaving.',
                      ),
                    ),
                  );
                }
              }),
            );
          } else {
            unawaited(_returnToBook());
          }
        }
      },
      child: guardedSurface,
    );
  }

  Future<void> _override(ContentType? type) async {
    if (type == null) return;
    setState(() => _saving = true);
    try {
      await prepareToLeave();
      await widget.onClassificationOverride!(type);
      if (mounted) {
        setState(() {
          content = content.withContentType(type);
          _puzzleMode = type == ContentType.puzzle ? StudyMode.reading : null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classification could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

final class _UnavailableMode extends StatelessWidget {
  const _UnavailableMode({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
