import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

/// Renders a note's Markdown off-screen and captures it as PNG bytes, so the
/// caller can save it via a save-as dialog. Mirrors the chat message image
/// export: build the content inside a transient [OverlayEntry] positioned far
/// off-screen, wait a few frames for async layout (images, math, code), then
/// snapshot the [RepaintBoundary].
///
/// Returns null if rendering fails. [markdown] is rendered through the shared
/// [AppMarkdown] so the image matches the in-app preview.
Future<Uint8List?> renderNoteAsPngBytes(
  BuildContext context, {
  required String title,
  required String markdown,
}) async {
  final theme = Theme.of(context);
  const double width = 720;
  const double pixelRatio = 2.0;
  final boundaryKey = GlobalKey();

  Widget buildContent() {
    final cs = theme.colorScheme;
    return Container(
      width: width,
      color: cs.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppMarkdown(content: markdown),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'AetherLink',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final overlay = Overlay.of(context);
  final completer = Completer<void>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      var frameCount = 0;
      void scheduleCompletion() {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          frameCount++;
          if (frameCount < 4) {
            scheduleCompletion();
          } else if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }

      scheduleCompletion();

      return Positioned(
        left: -10000,
        top: -10000,
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.noScaling),
          child: Theme(
            data: theme,
            child: RepaintBoundary(key: boundaryKey, child: buildContent()),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  try {
    await completer.future.timeout(const Duration(seconds: 6));
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}
