import 'package:flutter/foundation.dart';

/// A single ATX heading (`#`…`######`) parsed from a note's Markdown, used to
/// build the editor's table-of-contents outline.
@immutable
class NoteHeading {
  const NoteHeading({
    required this.level,
    required this.text,
    required this.offset,
  });

  /// Heading depth, 1–6.
  final int level;

  /// The heading text with leading `#`s and trailing `#`s stripped.
  final String text;

  /// Character offset of the start of the heading line in the source, so the
  /// editor can place the cursor / scroll there.
  final int offset;
}

/// Parses ATX headings from [markdown], skipping anything inside fenced code
/// blocks (``` or ~~~). Pure Dart so it stays in the domain layer and is
/// trivially testable. Returns headings in document order.
List<NoteHeading> parseOutline(String markdown) {
  if (markdown.isEmpty) return const <NoteHeading>[];
  final headings = <NoteHeading>[];
  var offset = 0;
  String? fence; // active code-fence marker (``` or ~~~), or null

  for (final line in markdown.split('\n')) {
    final trimmed = line.trimLeft();

    // Toggle fenced code-block state on ``` / ~~~ lines.
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      final marker = trimmed.substring(0, 3);
      if (fence == null) {
        fence = marker;
      } else if (trimmed.startsWith(fence)) {
        fence = null;
      }
      offset += line.length + 1;
      continue;
    }

    if (fence == null) {
      final match = _headingPattern.firstMatch(line);
      if (match != null) {
        final level = match.group(1)!.length;
        final text = match.group(2)!.replaceAll(_trailingHashes, '').trim();
        if (text.isNotEmpty) {
          headings.add(NoteHeading(level: level, text: text, offset: offset));
        }
      }
    }

    offset += line.length + 1; // +1 for the consumed '\n'
  }
  return headings;
}

/// `#`…`######` followed by at least one space, then the heading text.
final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');

/// Trailing closing hashes of a closed ATX heading (`## Title ##`).
final RegExp _trailingHashes = RegExp(r'\s*#+\s*$');
