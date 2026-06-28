import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

/// Regression test for the debug-only layout crash on messages containing a
/// markdown table (e.g. an assistant listing its tools as a table).
///
/// Cells render `GptMarkdown`, which wraps content in a `LayoutBuilder`.
/// `LayoutBuilder` doesn't support the intrinsic-sizing protocol, so the old
/// `IntrinsicWidth(child: table)` triggered "RenderBox was not laid out" /
/// relayout-boundary assertions in debug (silently returning 0 in release).
void main() {
  testWidgets('MarkdownTable renders without intrinsic-sizing crash', (
    tester,
  ) async {
    final rows = <CustomTableRow>[
      CustomTableRow(
        isHeader: true,
        fields: [
          CustomTableField(data: '工具'),
          CustomTableField(data: '说明'),
        ],
      ),
      CustomTableRow(
        fields: [
          CustomTableField(data: '`read_file`'),
          CustomTableField(
            data: '读取**工作区**文件内容，支持非常非常非常非常非常非常非常非常长的描述文本',
          ),
        ],
      ),
      CustomTableRow(
        fields: [
          CustomTableField(data: 'list_files'),
          CustomTableField(data: '列出目录下的文件'),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: GptMarkdownTheme(
                gptThemeData: GptMarkdownThemeData(brightness: Brightness.light),
                child: MarkdownTable(
                  rows: rows,
                  baseStyle: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownTable), findsOneWidget);
  });
}
