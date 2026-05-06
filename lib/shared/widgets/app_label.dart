import 'package:flutter/material.dart';
import 'package:last_launcher/shared/widgets/scanline_overlay.dart';

class AppLabel extends StatelessWidget {
  const AppLabel({
    required this.label,
    this.onTap,
    this.onLongPress,
    this.leading,
    this.textDecoration,
    this.decorationThickness,
    this.opacity = 1.0,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final TextDecoration? textDecoration;
  final double? decorationThickness;
  final double opacity;

  static const fontSize = 28.0;
  static const verticalPadding = 9.0;

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
      child: _GlitchText(label: label, style: style),
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

    return opacity < 1.0 ? Opacity(opacity: opacity, child: content) : content;
  }
}

class _GlitchText extends StatefulWidget {
  const _GlitchText({required this.label, required this.style});

  final String label;
  final TextStyle? style;

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> {
  // Lazily allocated only when the Extra theme is active. Saves one
  // GlobalKey per list item in the regular themes (drawer/home/tasks lists).
  GlobalKey? _key;

  double _getIntensity(ScanlineScope scope, GlobalKey key) {
    // Only glitch ~40% of labels per sweep, based on label hash + band position.
    if ((widget.label.hashCode + scope.bandY.toInt()) % 5 < 3) return 0;

    try {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) return 0;

      final globalY = box.localToGlobal(Offset.zero).dy;
      final widgetHeight = box.size.height;
      final bandTop = scope.bandY;
      final bandBottom = bandTop + scope.bandHeight;

      if (bandBottom < globalY || bandTop > globalY + widgetHeight) return 0;

      final overlapCenter =
          ((bandTop + bandBottom) / 2 - globalY) / widgetHeight;
      return (1 - (overlapCenter - 0.5).abs() * 2).clamp(0.0, 0.25);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = ScanlineScope.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Key? textKey;
    double intensity = 0;
    if (scope != null && !reduceMotion) {
      final key = _key ??= GlobalKey();
      textKey = key;
      intensity = _getIntensity(scope, key);
    }

    return Semantics(
      label: widget.label,
      excludeSemantics: true,
      child: Text(
        key: textKey,
        intensity > 0 ? glitchText(widget.label, intensity) : widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      ),
    );
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
