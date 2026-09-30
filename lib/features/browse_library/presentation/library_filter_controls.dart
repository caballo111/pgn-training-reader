import 'package:flutter/material.dart';

import '../../../domain/chess_content/content_type.dart';
import '../../../domain/chess_content/pgn_source.dart';
import '../application/library_query.dart';

/// Accessible filters for indexed PGN metadata.
final class LibraryFilterControls extends StatelessWidget {
  const LibraryFilterControls({
    super.key,
    required this.query,
    required this.sources,
    required this.onChanged,
  });
  final LibraryQuery query;
  final List<PgnSource> sources;
  final ValueChanged<LibraryQuery> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      _dropdown<ContentType?>(
        label: 'Content type',
        value: query.contentType,
        entries: const [null, ...ContentType.values],
        title: (value) =>
            value == null ? 'All content types' : _title(value.name),
        changed: (value) => onChanged(
          value == null
              ? query.copyWith(clearContentType: true)
              : query.copyWith(contentType: value),
        ),
      ),
      _textFilter(
        'Section',
        query.section,
        (v) => onChanged(query.copyWith(section: v, clearSection: v.isEmpty)),
      ),
      _textFilter(
        'Theme',
        query.theme,
        (v) => onChanged(query.copyWith(theme: v, clearTheme: v.isEmpty)),
      ),
      _textFilter(
        'Difficulty',
        query.difficulty,
        (v) => onChanged(
          query.copyWith(difficulty: v, clearDifficulty: v.isEmpty),
        ),
      ),
      _textFilter(
        'Result',
        query.result,
        (v) => onChanged(query.copyWith(result: v, clearResult: v.isEmpty)),
      ),
      _dropdown<String?>(
        label: 'Source',
        value: query.sourceId,
        entries: [null, ...sources.map((source) => source.id)],
        title: (id) => id == null
            ? 'All sources'
            : sources.firstWhere((s) => s.id == id).displayName,
        changed: (id) => onChanged(
          id == null
              ? query.copyWith(clearSourceId: true)
              : query.copyWith(sourceId: id),
        ),
      ),
    ],
  );

  Widget _textFilter(
    String label,
    String? value,
    ValueChanged<String> changed,
  ) => _TextFilter(label: label, value: value, onChanged: changed);

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> entries,
    required String Function(T) title,
    required ValueChanged<T> changed,
  }) => SizedBox(
    width: 190,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: entries
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(title(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null || entries.contains(null)) changed(next as T);
      },
    ),
  );

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

final class _TextFilter extends StatefulWidget {
  const _TextFilter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextFilter> createState() => _TextFilterState();
}

final class _TextFilterState extends State<_TextFilter> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );

  @override
  void didUpdateWidget(covariant _TextFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextValue = widget.value ?? '';
    if (nextValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: nextValue,
        selection: TextSelection.collapsed(offset: nextValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onChanged,
      onChanged: widget.onChanged,
    ),
  );
}
