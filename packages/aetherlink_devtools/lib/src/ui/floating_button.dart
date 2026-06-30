import 'package:flutter/material.dart';

/// Wraps [child] with the draggable developer-tools entry button when [enabled].
///
/// Drop this in `MaterialApp.builder` (alongside `PerfOverlayHost`) so the button
/// floats above every route. When disabled it returns [child] untouched (zero
/// overhead). [onPressed] is supplied by the host (it navigates to the DevTools
/// page) so the package stays free of any router dependency.
class DevToolsFloatingButtonHost extends StatelessWidget {
  const DevToolsFloatingButtonHost({
    super.key,
    required this.child,
    required this.enabled,
    required this.onPressed,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.expand,
      children: [child, DevToolsFloatingButton(onPressed: onPressed)],
    );
  }
}

/// A 48px round, draggable button (Terminal glyph) that opens the DevTools page.
/// Visual language mirrors the original web `DevToolsFloatingButton` (blue
/// translucent circle). Drag to move; tap to open. Position is remembered for the
/// session, matching `PerfOverlay`.
class DevToolsFloatingButton extends StatefulWidget {
  const DevToolsFloatingButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<DevToolsFloatingButton> createState() => _DevToolsFloatingButtonState();
}

class _DevToolsFloatingButtonState extends State<DevToolsFloatingButton> {
  // Remembered for the session so the button keeps its spot across rebuilds.
  // Defaults just below the perf overlay's start (12, 80) so they don't overlap.
  static Offset _position = const Offset(12, 140);

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxX = media.size.width - _size;
    final maxY = media.size.height - _size;
    final left = _position.dx.clamp(0.0, maxX > 0 ? maxX : 0.0);
    final top = _position.dy.clamp(media.padding.top, maxY > 0 ? maxY : 0.0);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => setState(() => _position += d.delta),
        onTap: widget.onPressed,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              color: const Color(0xE62196F3), // blue, ~0.9 alpha
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.terminal, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
