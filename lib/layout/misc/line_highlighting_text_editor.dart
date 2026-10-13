import 'package:flutter/material.dart';

/// An editable text field that can highlight a specific source line.
///
/// Line indices are zero-based:
/// - 0 = first line
/// - 1 = second line
/// - -1 = no highlighted line
///
/// The highlight is applied to the text layout itself, not a positioned
/// overlay, so it naturally follows scrolling and text editing.
class LineHighlightingTextEditor extends StatefulWidget {
  final String initialText;
  final TextEditingController? controller;

  final int highlightedLine;
  final Color highlightColor;
  final Color highlightTextColor;

  final TextStyle? style;
  final TextStyle? hintStyle;
  final String? hintText;

  final EdgeInsetsGeometry contentPadding;
  final bool expands;
  final int? minLines;
  final int? maxLines;
  final TextInputType keyboardType;

  final ValueChanged<String>? onChanged;
  final InputDecoration decoration;

  const LineHighlightingTextEditor({
    super.key,
    this.initialText = '',
    this.controller,
    this.highlightedLine = -1,
    required this.highlightColor,
    required this.highlightTextColor,
    this.style,
    this.hintStyle,
    this.hintText,
    this.contentPadding = const EdgeInsets.all(12),
    this.expands = false,
    this.minLines = 1,
    this.maxLines,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.decoration = const InputDecoration(),
  });

  @override
  State<LineHighlightingTextEditor> createState() =>
      _LineHighlightingTextEditorState();
}

class _LineHighlightingTextEditorState
    extends State<LineHighlightingTextEditor> {
  late final _HighlightingController _internalController;
  late final bool _ownsController;

  TextEditingController get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();

    _ownsController = widget.controller == null;
    _internalController = _HighlightingController(text: widget.initialText);

    _configureController();
  }

  @override
  void didUpdateWidget(covariant LineHighlightingTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _configureController();
    } else if (oldWidget.highlightedLine != widget.highlightedLine ||
        oldWidget.highlightColor != widget.highlightColor ||
        oldWidget.highlightTextColor != widget.highlightTextColor) {
      _configureController();
    }
  }

  void _configureController() {
    final controller = _controller;

    if (controller is _HighlightingController) {
      controller
        ..highlightedLine = widget.highlightedLine
        ..highlightColor = widget.highlightColor
        ..highlightTextColor = widget.highlightTextColor;
    }
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _configureController();

    final effectiveDecoration = widget.decoration.copyWith(
      hintText: widget.hintText ?? widget.decoration.hintText,
      hintStyle: widget.hintStyle ?? widget.decoration.hintStyle,
      contentPadding: widget.contentPadding,
    );

    return TextField(
      controller: _controller,
      expands: widget.expands,
      minLines: widget.expands ? null : widget.minLines,
      maxLines: widget.expands ? null : widget.maxLines,
      keyboardType: widget.keyboardType,
      style: widget.style,
      decoration: effectiveDecoration,
      onChanged: widget.onChanged,
    );
  }
}

class _HighlightingController extends TextEditingController {
  _HighlightingController({super.text});

  int highlightedLine = -1;
  Color highlightColor = Colors.transparent;
  Color highlightTextColor = Colors.white;
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final value = text;

    if (value.isEmpty ||
        highlightedLine < 0 ||
        highlightedLine >= value.split('\n').length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final lines = value.split('\n');
    final spans = <InlineSpan>[];

    for (var i = 0; i < lines.length; i++) {
      spans.add(
        TextSpan(
          text: lines[i],
          style: i == highlightedLine
              ? TextStyle(
                  backgroundColor: highlightColor,
                  color: highlightTextColor,
                )
              : null,
        ),
      );

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: style, children: spans);
  }
}
