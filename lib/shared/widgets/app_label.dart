import 'package:flutter/material.dart';
import 'package:last_launcher/shared/data/hints.dart';

class AppLabel extends StatelessWidget {
  const AppLabel({
    required this.label,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.textDecoration,
    this.decorationThickness,
    this.opacity = 1.0,
    this.hint,
    this.hintOpacity = 0.6,
    this.hintAlphaOnly = false,
    this.textAlign = TextAlign.start,
    this.fontSize = defaultFontSize,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final TextDecoration? textDecoration;
  final double? decorationThickness;
  final double opacity;
  final SubstringHint? hint;
  final double hintOpacity;
  final bool hintAlphaOnly;
  final TextAlign textAlign;
  final double fontSize;

  static const double defaultFontSize = 35.0;
  static const double verticalPadding = 9.0;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontSize: fontSize,
      decoration: textDecoration,
      decorationThickness: decorationThickness,
    );

    final text = Padding(
      padding: EdgeInsets.only(
        left: leading == null ? 20 : 0,
        right: 20,
        top: verticalPadding,
        bottom: verticalPadding,
      ),
      child: _AppLabelText(
        label: label,
        style: style,
        hint: hint,
        hintOpacity: hintOpacity,
        hintAlphaOnly: hintAlphaOnly,
        textOpacity: opacity,
        textAlign: textAlign,
      ),
    );

    final tappable = Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        focusColor: Theme.of(context).colorScheme.onSurface.withAlpha(30),
        child: text,
      ),
    );

    final content = leading == null
        ? tappable
        : Row(
            children: [
              leading!,
              Expanded(child: tappable),
            ],
          );

    return content;
  }
}

class _AppLabelText extends StatelessWidget {
  const _AppLabelText({
    required this.label,
    required this.style,
    this.hint,
    this.hintOpacity = 0.6,
    this.hintAlphaOnly = false,
    this.textOpacity = 1.0,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final TextStyle? style;
  final SubstringHint? hint;
  final double hintOpacity;
  final bool hintAlphaOnly;
  final double textOpacity;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    final style = this.style;

    if (style == null) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    if (hint != null && hint.start + hint.length <= label.length) {
      final before = label.substring(0, hint.start);
      final match = label.substring(
        hint.start,
        hint.start + hint.length,
      );
      final after = label.substring(hint.start + hint.length);
      final dimAlpha = (hintOpacity * 255).round();
      final dimmedStyle = style.copyWith(
        color: style.color?.withAlpha(dimAlpha),
      );

      return Text.rich(
        TextSpan(
          style: style,
          children: [
            if (before.isNotEmpty)
              TextSpan(text: before, style: dimmedStyle),
            ..._hintSpans(match, style, dimAlpha),
            if (after.isNotEmpty)
              TextSpan(text: after, style: dimmedStyle),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    if (textOpacity < 1.0) {
      final dimAlpha = (textOpacity * 255).round();

      return Text.rich(
        TextSpan(
          style: style.copyWith(color: style.color?.withAlpha(dimAlpha)),
          text: label,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
  }

  List<TextSpan> _hintSpans(String match, TextStyle style, int dimAlpha) {
    if (!hintAlphaOnly) return [TextSpan(text: match)];

    final dimmedStyle = style.copyWith(color: style.color?.withAlpha(dimAlpha));
    final spans = <TextSpan>[];
    int start = 0;

    for (int i = 0; i <= match.length; i++) {
      if (i == match.length || !RegExp(r'[a-zA-Z]').hasMatch(match[i])) {
        if (start < i) {
          spans.add(TextSpan(text: match.substring(start, i)));
        }
        if (i < match.length) {
          spans.add(TextSpan(text: match[i], style: dimmedStyle));
        }
        start = i + 1;
      }
    }
    return spans;
  }
}

Widget dragProxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) {
  return Material(
    color: Colors.transparent,
    child: Opacity(opacity: 0.6, child: child),
  );
}

Widget dragHandle(BuildContext context, int index) {
  return ReorderableDragStartListener(
    index: index,
    child: SizedBox.square(
      dimension: 48,
      child: Center(
        child: Icon(
          Icons.drag_indicator,
          size: 22,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(130),
        ),
      ),
    ),
  );
}
