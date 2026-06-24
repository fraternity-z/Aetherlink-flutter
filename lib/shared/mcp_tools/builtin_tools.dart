import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/math_expression.dart';

/// Local execution for the pure-computation built-in MCP servers — the port of
/// `CalculatorServer` / `TimeServer` (`src/shared/services/mcp/servers/`). The
/// chat tool-call loop (Phase C) routes a built-in tool call here; the settings
/// detail page only lists the catalog (`builtin_tool_catalog.dart`).
///
/// Returns `null` for servers that aren't locally runnable (external servers,
/// or `@aether/calendar` / `@aether/alarm`, which need native device plugins).
///
/// [env] is the server's configured environment (e.g. `SEARXNG_BASE_URL`).
Future<McpToolResult?> runBuiltinTool(
  String serverName,
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
  Map<String, String>? env,
}) async {
  switch (serverName) {
    case '@aether/calculator':
      return runCalculatorTool(toolName, args);
    case '@aether/time':
      return runTimeTool(toolName, args, now: now);
    case '@aether/searxng':
      return runSearxngTool(toolName, args, env: env);
    case '@aether/fetch':
      return runFetchTool(toolName, args);
    case '@aether/metaso-search':
      return runMetasoTool(toolName, args, env: env);
    case '@aether/grok-search':
      return runGrokSearchTool(toolName, args, env: env);
  }
  return null;
}

/// `@aether/calculator` tool execution (`calculate` / `convert_base` /
/// `convert_unit` / `statistics`).
McpToolResult runCalculatorTool(String toolName, Map<String, Object?> args) {
  switch (toolName) {
    case 'calculate':
      return _calculate(args);
    case 'convert_base':
      return _convertBase(args);
    case 'convert_unit':
      return _convertUnit(args);
    case 'statistics':
      return _statistics(args);
  }
  return McpToolResult(
    _encode({'success': false, 'error': '未知的工具: $toolName'}),
    isError: true,
  );
}

/// `@aether/time` tool execution (`get_current_time`). [now] is injectable for
/// deterministic tests; it defaults to the wall clock.
McpToolResult runTimeTool(
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
}) {
  if (toolName == 'get_current_time') {
    return _getCurrentTime(args, now ?? DateTime.now());
  }
  return McpToolResult('获取时间失败: 未知的工具: $toolName');
}

// ── Calculator ──────────────────────────────────────────────────────────────

McpToolResult _calculate(Map<String, Object?> args) {
  final expression = (args['expression'] as String?)?.trim() ?? '';
  try {
    final result = evaluateMathExpression(expression);
    if (!result.isFinite) throw const FormatException('无效的数学表达式');
    return McpToolResult(
      _encode({
        'success': true,
        'expression': expression,
        'result': _normNum(result),
        'formatted': _formatNumber(result),
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({
        'success': false,
        'expression': expression,
        'error': _errMsg(error, '计算错误'),
      }),
      isError: true,
    );
  }
}

McpToolResult _convertBase(Map<String, Object?> args) {
  try {
    final value = '${args['value']}';
    final fromBase = _asInt(args['fromBase']);
    final toBase = _asInt(args['toBase']);
    const allowed = {2, 8, 10, 16};
    if (!allowed.contains(fromBase) || !allowed.contains(toBase)) {
      throw const FormatException('只支持 2, 8, 10, 16 进制');
    }
    final decimal = int.tryParse(value.trim(), radix: fromBase);
    if (decimal == null) throw const FormatException('无效的数值');
    var result = decimal.toRadixString(toBase);
    if (toBase == 16) result = result.toUpperCase();
    return McpToolResult(
      _encode({
        'success': true,
        'input': {'value': value, 'base': fromBase},
        'output': {'value': result, 'base': toBase},
        'decimal': decimal,
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '进制转换失败')}),
      isError: true,
    );
  }
}

McpToolResult _convertUnit(Map<String, Object?> args) {
  try {
    final value = _asDouble(args['value']);
    final category = (args['category'] as String?) ?? '';
    final fromUnit = (args['fromUnit'] as String?) ?? '';
    final toUnit = (args['toUnit'] as String?) ?? '';
    final result = switch (category) {
      'length' => _convertFactor(
        value,
        fromUnit,
        toUnit,
        _lengthToMeters,
        '长度',
      ),
      'weight' => _convertFactor(value, fromUnit, toUnit, _weightToKg, '重量'),
      'temperature' => _convertTemperature(value, fromUnit, toUnit),
      'area' => _convertFactor(value, fromUnit, toUnit, _areaToSqMeters, '面积'),
      'volume' => _convertFactor(
        value,
        fromUnit,
        toUnit,
        _volumeToLiters,
        '体积',
      ),
      _ => throw FormatException('不支持的单位类别: $category'),
    };
    return McpToolResult(
      _encode({
        'success': true,
        'input': '${_numStr(value)} $fromUnit',
        'output': '${_numStr(result)} $toUnit',
        'result': _normNum(result),
        'category': category,
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '单位转换失败')}),
      isError: true,
    );
  }
}

McpToolResult _statistics(Map<String, Object?> args) {
  try {
    final raw = args['numbers'];
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('请提供有效的数字数组');
    }
    final numbers = raw.map(_asDouble).toList();
    final n = numbers.length;
    final sorted = [...numbers]..sort();
    final sum = numbers.reduce((a, b) => a + b);
    final mean = sum / n;
    final median = n.isEven
        ? (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2
        : sorted[n ~/ 2];
    final variance =
        numbers
            .map((v) => math.pow(v - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        n;
    final stdDev = math.sqrt(variance);
    final maxV = numbers.reduce(math.max);
    final minV = numbers.reduce(math.min);
    return McpToolResult(
      _encode({
        'success': true,
        'count': n,
        'sum': _normNum(sum),
        'mean': _normNum(mean),
        'median': _normNum(median),
        'mode': _mode(numbers),
        'variance': _normNum(variance),
        'standardDeviation': _normNum(stdDev),
        'min': _normNum(minV),
        'max': _normNum(maxV),
        'range': _normNum(maxV - minV),
        'sorted': sorted.map(_normNum).toList(),
      }),
    );
  } catch (error) {
    return McpToolResult(
      _encode({'success': false, 'error': _errMsg(error, '统计计算失败')}),
      isError: true,
    );
  }
}

const Map<String, double> _lengthToMeters = {
  'mm': 0.001,
  'cm': 0.01,
  'm': 1,
  'km': 1000,
  'inch': 0.0254,
  'foot': 0.3048,
  'yard': 0.9144,
  'mile': 1609.344,
};

const Map<String, double> _weightToKg = {
  'mg': 0.000001,
  'g': 0.001,
  'kg': 1,
  'ton': 1000,
  'oz': 0.0283495,
  'lb': 0.453592,
  'pound': 0.453592,
};

const Map<String, double> _areaToSqMeters = {
  'sqmm': 0.000001,
  'sqcm': 0.0001,
  'sqm': 1,
  'sqkm': 1000000,
  'sqinch': 0.00064516,
  'sqfoot': 0.092903,
  'sqyard': 0.836127,
  'acre': 4046.86,
  'hectare': 10000,
};

const Map<String, double> _volumeToLiters = {
  'ml': 0.001,
  'l': 1,
  'm3': 1000,
  'gallon': 3.78541,
  'quart': 0.946353,
  'pint': 0.473176,
  'cup': 0.236588,
  'floz': 0.0295735,
};

double _convertFactor(
  double value,
  String from,
  String to,
  Map<String, double> table,
  String label,
) {
  final f = table[from];
  final t = table[to];
  if (f == null || t == null) {
    throw FormatException('不支持的$label单位: $from 或 $to');
  }
  return value * f / t;
}

double _convertTemperature(double value, String from, String to) {
  double celsius;
  switch (from.toLowerCase()) {
    case 'celsius':
    case 'c':
      celsius = value;
    case 'fahrenheit':
    case 'f':
      celsius = (value - 32) * 5 / 9;
    case 'kelvin':
    case 'k':
      celsius = value - 273.15;
    default:
      throw FormatException('不支持的温度单位: $from');
  }
  switch (to.toLowerCase()) {
    case 'celsius':
    case 'c':
      return celsius;
    case 'fahrenheit':
    case 'f':
      return celsius * 9 / 5 + 32;
    case 'kelvin':
    case 'k':
      return celsius + 273.15;
    default:
      throw FormatException('不支持的温度单位: $to');
  }
}

Object? _mode(List<double> numbers) {
  final frequency = <double, int>{};
  var maxFreq = 0;
  double? mode;
  for (final num in numbers) {
    final freq = (frequency[num] ?? 0) + 1;
    frequency[num] = freq;
    if (freq > maxFreq) {
      maxFreq = freq;
      mode = num;
    }
  }
  return maxFreq > 1 ? _normNum(mode!) : null;
}

// ── Time ──────────────────────────────────────────────────────────────────

McpToolResult _getCurrentTime(Map<String, Object?> args, DateTime now) {
  try {
    final format = (args['format'] as String?) ?? 'locale';
    final timezone = args['timezone'] as String?;
    final local = now.toLocal();
    String timeString;
    final additional = <String, Object?>{};
    switch (format) {
      case 'iso':
        timeString = now.toUtc().toIso8601String();
      case 'timestamp':
        final ms = now.millisecondsSinceEpoch;
        timeString = ms.toString();
        additional['milliseconds'] = ms;
        additional['seconds'] = ms ~/ 1000;
      case 'locale':
      default:
        timeString = _formatLocale(local);
        if (timezone != null && timezone.isNotEmpty) {
          additional['timezone'] = timezone;
          additional['note'] = '时区转换暂未支持（需时区数据库），返回设备本地时间';
        }
    }
    return McpToolResult(
      _encode({
        'currentTime': timeString,
        'format': format,
        'year': local.year,
        'month': local.month,
        'day': local.day,
        'weekday': _weekdayCn(local.weekday),
        'hour': local.hour,
        'minute': local.minute,
        'second': local.second,
        ...additional,
      }),
    );
  } catch (error) {
    return McpToolResult('获取时间失败: ${_errMsg(error, '未知错误')}');
  }
}

String _formatLocale(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}/${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

const List<String> _weekdays = [
  '星期一',
  '星期二',
  '星期三',
  '星期四',
  '星期五',
  '星期六',
  '星期日',
];

String _weekdayCn(int weekday) => _weekdays[(weekday - 1) % 7];

// ── Shared helpers ──────────────────────────────────────────────────────────

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

String _encode(Object? value) => _jsonEncoder.convert(value);

/// Collapses integer-valued doubles to `int` so JSON renders `5`, not `5.0`
/// (matching the web's `JSON.stringify` of JS numbers).
Object _normNum(num value) {
  if (value is int) return value;
  final d = value.toDouble();
  if (d.isFinite && d == d.truncateToDouble()) return d.toInt();
  return d;
}

String _numStr(num value) {
  final normalized = _normNum(value);
  return normalized.toString();
}

/// Mirrors `CalculatorServer.formatNumber`: integers as-is, otherwise up to 10
/// decimals with trailing zeros trimmed.
String _formatNumber(double n) {
  if (!n.isFinite) return n.toString();
  if (n == n.truncateToDouble()) return n.toInt().toString();
  final trimmed = double.parse(n.toStringAsFixed(10));
  if (trimmed == trimmed.truncateToDouble()) return trimmed.toInt().toString();
  return trimmed.toString();
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的整数: $value');
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  throw FormatException('无效的数值: $value');
}

String _errMsg(Object error, String fallback) {
  if (error is FormatException) {
    final message = error.message;
    if (message.isNotEmpty) return message;
  }
  return fallback;
}

// ── SearXNG ─────────────────────────────────────────────────────────────────

const String _kDefaultSearxngUrl = 'http://154.37.208.52:39281';

/// `@aether/searxng` tool execution (`searxng_search` / `searxng_read_url`).
Future<McpToolResult> runSearxngTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  final baseUrl = env?['SEARXNG_BASE_URL'] ?? _kDefaultSearxngUrl;
  switch (toolName) {
    case 'searxng_search':
      return _searxngSearch(args, baseUrl);
    case 'searxng_read_url':
      return _searxngReadUrl(args);
  }
  return McpToolResult('未知的工具: $toolName', isError: true);
}

Future<McpToolResult> _searxngSearch(
  Map<String, Object?> args,
  String baseUrl,
) async {
  try {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词不能为空', isError: true);
    }
    final engines = args['engines'] as String?;
    final language = (args['language'] as String?) ?? 'zh-CN';
    final categories = (args['categories'] as String?) ?? 'general';
    final maxResults = _asIntOr(args['maxResults'], 10);
    final timeRange = args['timeRange'] as String?;
    final pageno = _asIntOr(args['pageno'], 1);
    final safesearch = _asIntOr(args['safesearch'], 0);

    final params = <String, String>{
      'q': query,
      'format': 'json',
      'language': language,
      'categories': categories,
      'pageno': '$pageno',
      'safesearch': '$safesearch',
    };
    if (engines != null && engines.isNotEmpty) params['engines'] = engines;
    if (timeRange != null && timeRange.isNotEmpty) {
      params['time_range'] = timeRange;
    }

    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: params);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          'SearXNG 搜索请求失败 (${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final rawResults = (data['results'] as List?) ?? [];
      final results = rawResults.take(maxResults).toList();
      final totalResults = data['number_of_results'] ?? results.length;
      final suggestions = (data['suggestions'] as List?)?.cast<String>() ?? [];
      final answers = (data['answers'] as List?)?.cast<String>() ?? [];
      final corrections = (data['corrections'] as List?)?.cast<String>() ?? [];
      final infoboxes = (data['infoboxes'] as List?) ?? [];

      final buf = StringBuffer();
      buf.writeln('## SearXNG 搜索结果\n');
      buf.writeln('**查询**: $query');
      buf.writeln('**结果数**: ${results.length} / $totalResults');
      buf.writeln('**页码**: $pageno');
      if (engines != null) buf.writeln('**引擎**: $engines');
      if (timeRange != null && timeRange.isNotEmpty) {
        buf.writeln('**时间范围**: $timeRange');
      }
      buf.writeln('\n---\n');

      if (answers.isNotEmpty) {
        buf.writeln('## 直接答案\n');
        for (final answer in answers) {
          buf.writeln('> $answer\n');
        }
        buf.writeln('---\n');
      }

      if (corrections.isNotEmpty) {
        buf.writeln('**拼写建议**: ${corrections.join(', ')}\n');
      }

      for (final box in infoboxes) {
        if (box is! Map) continue;
        buf.writeln('## ${box['infobox'] ?? '信息卡片'}\n');
        if (box['content'] != null) buf.writeln('${box['content']}\n');
        final urls = box['urls'];
        if (urls is List && urls.isNotEmpty) {
          buf.writeln('**相关链接**:');
          for (final u in urls) {
            if (u is Map) {
              buf.writeln('- [${u['title'] ?? u['url']}](${u['url']})');
            }
          }
          buf.writeln();
        }
        final attrs = box['attributes'];
        if (attrs is List && attrs.isNotEmpty) {
          for (final attr in attrs) {
            if (attr is Map) {
              buf.writeln('- **${attr['label']}**: ${attr['value']}');
            }
          }
          buf.writeln();
        }
        buf.writeln('---\n');
      }

      if (results.isNotEmpty) {
        for (var i = 0; i < results.length; i++) {
          final item = results[i];
          if (item is! Map) continue;
          buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
          if (item['url'] != null) buf.writeln('**链接**: ${item['url']}\n');
          if (item['content'] != null) {
            buf.writeln('**摘要**: ${item['content']}\n');
          }
          if (item['engine'] != null) {
            buf.writeln('**来源引擎**: ${item['engine']}');
          }
          if (item['score'] != null) {
            final score = (item['score'] as num).toDouble() * 100;
            buf.writeln('**相关度**: ${score.toStringAsFixed(1)}%');
          }
          if (item['publishedDate'] != null) {
            buf.writeln('**发布时间**: ${item['publishedDate']}');
          }
          buf.writeln('\n---\n');
        }
      } else {
        buf.writeln('未找到相关结果\n');
      }

      if (suggestions.isNotEmpty) {
        buf.writeln('## 相关搜索建议\n');
        for (final s in suggestions) {
          buf.writeln('- $s');
        }
        buf.writeln();
      }

      buf.write('*数据来源: SearXNG 元搜索引擎*');

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      'SearXNG 搜索失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      '请检查 SearXNG 服务是否正常运行。',
      isError: true,
    );
  }
}

Future<McpToolResult> _searxngReadUrl(Map<String, Object?> args) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final maxLength = _asIntOr(args['maxLength'], 5000);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set('User-Agent',
            'Mozilla/5.0 (compatible; AetherLink/1.0; +https://aetherlink.app)')
        ..set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          'HTTP 请求失败 (${response.statusCode}): ${response.reasonPhrase}',
          isError: true,
        );
      }

      final contentType =
          response.headers.contentType?.toString() ?? '';
      String extracted;
      String title = '';

      if (contentType.contains('json')) {
        try {
          final json = jsonDecode(body);
          extracted = const JsonEncoder.withIndent('  ').convert(json);
        } catch (_) {
          extracted = body;
        }
      } else if (contentType.contains('html')) {
        final parsed = _extractHtmlContent(body);
        title = parsed.title;
        extracted = parsed.content;
      } else {
        extracted = body;
      }

      if (extracted.length > maxLength) {
        extracted = '${extracted.substring(0, maxLength)}\n\n...(内容已截断)';
      }

      final buf = StringBuffer();
      buf.writeln('## 网页内容\n');
      buf.writeln('**URL**: $url');
      if (title.isNotEmpty) buf.writeln('**标题**: $title');
      buf.writeln('**内容长度**: ${extracted.length} 字符');
      buf.writeln('\n---\n');
      buf.write(extracted);

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '网页抓取失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

/// Lightweight HTML-to-text extraction (port of `SearXNGServer.extractContent`).
({String title, String content}) _extractHtmlContent(String html) {
  final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>', caseSensitive: false)
      .firstMatch(html);
  final title = titleMatch != null ? _decodeHtmlEntities(titleMatch.group(1)!.trim()) : '';

  var content = html;
  content = content.replaceAll(
    RegExp(
      r'<(script|style|nav|header|footer|aside|iframe|noscript|svg)[^>]*>[\s\S]*?</\1>',
      caseSensitive: false,
    ),
    '',
  );
  content = content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  content = content.replaceAll(RegExp(r'<[^>]+>'), '\n');
  content = _decodeHtmlEntities(content);

  content = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .where((line) => line.length > 10 || RegExp(r'[。！？.!?]$').hasMatch(line))
      .join('\n');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return (title: title, content: content.trim());
}

String _decodeHtmlEntities(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      );
}

int _asIntOr(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

// ── Fetch (Official MCP Pattern) ────────────────────────────────────────────

/// `@aether/fetch` tool execution — follows the official MCP fetch server
/// pattern (modelcontextprotocol/servers). Single `fetch` tool that retrieves
/// URL content and converts HTML to Markdown for LLM consumption.
/// Supports chunked reading via `start_index` for large pages.
Future<McpToolResult> runFetchTool(
  String toolName,
  Map<String, Object?> args,
) async {
  if (toolName != 'fetch') {
    return McpToolResult('未知的工具: $toolName', isError: true);
  }
  return _fetchAndConvert(args);
}

Future<McpToolResult> _fetchAndConvert(Map<String, Object?> args) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final maxLength = _asIntOr(args['max_length'], 5000);
    final startIndex = _asIntOr(args['start_index'], 0);
    final raw = args['raw'] == true;
    final customHeaders = args['headers'];
    final headers = <String, String>{};
    if (customHeaders is Map) {
      for (final entry in customHeaders.entries) {
        headers['${entry.key}'] = '${entry.value}';
      }
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers
        ..set('User-Agent',
            'ModelContextProtocol/1.0 (Fetch Tool; AetherLink)')
        ..set('Accept',
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
        ..set('Accept-Language', 'zh-CN,zh;q=0.9,en;q=0.8');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '获取 URL 失败: HTTP ${response.statusCode}\nURL: $url',
          isError: true,
        );
      }

      final contentType = response.headers.contentType?.toString() ?? '';
      String content;

      if (raw) {
        content = body;
      } else if (contentType.contains('json')) {
        try {
          final parsed = jsonDecode(body);
          content = const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          content = body;
        }
      } else if (contentType.contains('html') || body.trimLeft().startsWith('<')) {
        content = _htmlToMarkdown(body);
      } else {
        content = body;
      }

      final totalLength = content.length;
      if (startIndex >= totalLength) {
        return McpToolResult(
          'start_index ($startIndex) 超出内容长度 ($totalLength)\n'
          'URL: $url',
          isError: true,
        );
      }

      final endIndex = (startIndex + maxLength).clamp(0, totalLength);
      final slice = content.substring(startIndex, endIndex);
      final hasMore = endIndex < totalLength;

      final buf = StringBuffer(slice);
      if (hasMore) {
        buf.writeln();
        buf.writeln();
        buf.writeln('<content_truncated>');
        buf.writeln('已返回字符 $startIndex-$endIndex / 共 $totalLength 字符。');
        buf.write('如需继续阅读，请使用 start_index=$endIndex 再次调用。');
        buf.writeln('</content_truncated>');
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '获取 URL 失败: ${error is Exception ? error.toString() : '未知错误'}\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

/// Convert HTML to simplified Markdown — a lightweight port of the
/// readability + markdownify approach used by the official MCP fetch server.
String _htmlToMarkdown(String html) {
  final titleMatch = RegExp(
    r'<title[^>]*>([\s\S]*?)</title>',
    caseSensitive: false,
  ).firstMatch(html);
  final title = titleMatch != null
      ? _decodeHtmlEntities(titleMatch.group(1)!.trim())
      : '';

  var content = html;
  // Remove non-content elements
  content = content.replaceAll(
    RegExp(
      r'<(script|style|nav|header|footer|aside|iframe|noscript|svg)[^>]*>[\s\S]*?</\1>',
      caseSensitive: false,
    ),
    '',
  );
  content = content.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

  // Convert heading tags to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<h([1-6])[^>]*>([\s\S]*?)</h\1>', caseSensitive: false),
    (m) {
      final level = int.parse(m.group(1)!);
      final text = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      return '\n${'#' * level} $text\n';
    },
  );

  // Convert links to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>', caseSensitive: false),
    (m) {
      final href = m.group(1)!;
      final text = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (text.isEmpty) return '';
      return '[$text]($href)';
    },
  );

  // Convert images to Markdown
  content = content.replaceAllMapped(
    RegExp(r'<img[^>]*src="([^"]*)"[^>]*/?>',caseSensitive: false),
    (m) {
      final src = m.group(1)!;
      final altMatch = RegExp(r'alt="([^"]*)"').firstMatch(m.group(0)!);
      final alt = altMatch?.group(1) ?? '';
      return '![${alt.isEmpty ? 'image' : alt}]($src)';
    },
  );

  // Convert list items
  content = content.replaceAllMapped(
    RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false),
    (m) => '\n- ${m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}',
  );

  // Convert <br> to newline
  content = content.replaceAll(
    RegExp(r'<br\s*/?>',caseSensitive: false),
    '\n',
  );

  // Convert <p> to paragraphs
  content = content.replaceAllMapped(
    RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false),
    (m) => '\n\n${m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}\n',
  );

  // Convert bold/strong
  content = content.replaceAllMapped(
    RegExp(r'<(strong|b)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '**${m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}**',
  );

  // Convert italic/em
  content = content.replaceAllMapped(
    RegExp(r'<(em|i)[^>]*>([\s\S]*?)</\1>', caseSensitive: false),
    (m) => '*${m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}*',
  );

  // Convert code blocks
  content = content.replaceAllMapped(
    RegExp(r'<pre[^>]*><code[^>]*>([\s\S]*?)</code></pre>', caseSensitive: false),
    (m) => '\n```\n${_decodeHtmlEntities(m.group(1)!)}\n```\n',
  );
  content = content.replaceAllMapped(
    RegExp(r'<code[^>]*>([\s\S]*?)</code>', caseSensitive: false),
    (m) => '`${_decodeHtmlEntities(m.group(1)!)}`',
  );

  // Strip remaining tags
  content = content.replaceAll(RegExp(r'<[^>]+>'), '');
  content = _decodeHtmlEntities(content);

  // Clean up whitespace
  content = content
      .split('\n')
      .map((line) => line.trim())
      .join('\n');
  content = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  final buf = StringBuffer();
  if (title.isNotEmpty) buf.writeln('# $title\n');
  buf.write(content.trim());
  return buf.toString();
}

// ── Metaso Search (秘塔AI搜索 Official API) ─────────────────────────────────

/// `@aether/metaso-search` tool execution — uses the official Metaso API
/// (metaso.cn/api/v1/*). Docs: https://metaso.cn/search-api/playground
Future<McpToolResult> runMetasoTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  final apiKey = env?['METASO_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    return const McpToolResult(
      '未配置 METASO_API_KEY 环境变量。\n\n'
      '获取方法：\n'
      '1. 访问 https://metaso.cn/search-api/api-keys\n'
      '2. 登录并创建 API Key（格式 mk-xxxx）\n'
      '3. 在 MCP 服务器环境变量中设置 METASO_API_KEY\n\n'
      '定价：0.03元/次查询',
      isError: true,
    );
  }
  switch (toolName) {
    case 'metaso_search':
      return _metasoSearch(args, apiKey);
    case 'metaso_reader':
      return _metasoReader(args, apiKey);
    case 'metaso_chat':
      return _metasoChat(args, apiKey);
  }
  return McpToolResult('未知的工具: $toolName', isError: true);
}

Future<McpToolResult> _metasoSearch(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final query = (args['q'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词 (q) 不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final size = _asIntOr(args['size'], 10);
    final page = _asIntOr(args['page'], 1);
    final includeSummary = args['includeSummary'] == true;
    final includeRawContent = args['includeRawContent'] == true;
    final conciseSnippet = args['conciseSnippet'] == true;

    final requestBody = jsonEncode({
      'q': query,
      'scope': scope,
      'size': size,
      'page': page,
      'includeSummary': includeSummary,
      'includeRawContent': includeRawContent,
      'conciseSnippet': conciseSnippet,
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/search'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔搜索请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final webpages = (data['webpages'] as List?) ?? [];
      final total = data['total'] ?? webpages.length;
      final credits = data['credits'];

      final buf = StringBuffer();
      buf.writeln('## 秘塔AI搜索结果\n');
      buf.writeln('**查询**: $query');
      buf.writeln('**范围**: $scope | **页码**: $page');
      buf.writeln('**结果数**: ${webpages.length} / $total');
      if (credits != null) buf.writeln('**积分消耗**: $credits');
      buf.writeln('\n---\n');

      if (webpages.isNotEmpty) {
        for (var i = 0; i < webpages.length; i++) {
          final item = webpages[i];
          if (item is! Map) continue;
          buf.writeln('### ${i + 1}. ${item['title'] ?? '无标题'}\n');
          if (item['link'] != null) buf.writeln('**链接**: ${item['link']}');
          if (item['snippet'] != null) buf.writeln('**摘要**: ${item['snippet']}');
          if (item['summary'] != null) buf.writeln('**AI摘要**: ${item['summary']}');
          if (includeRawContent && item['rawContent'] != null) {
            final rawContent = '${item['rawContent']}';
            final truncated = rawContent.length > 500
                ? '${rawContent.substring(0, 500)}...'
                : rawContent;
            buf.writeln('**原文**: $truncated');
          }
          if (item['score'] != null) buf.writeln('**相关度**: ${item['score']}');
          if (item['date'] != null) buf.writeln('**日期**: ${item['date']}');
          if (item['authors'] is List && (item['authors'] as List).isNotEmpty) {
            buf.writeln('**作者**: ${(item['authors'] as List).join(', ')}');
          }
          buf.writeln('\n---\n');
        }
      } else {
        buf.writeln('未找到相关结果\n');
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔AI搜索失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

Future<McpToolResult> _metasoReader(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final url = (args['url'] as String?)?.trim() ?? '';
    if (url.isEmpty) {
      return const McpToolResult('URL 不能为空', isError: true);
    }
    final format = (args['format'] as String?) ?? 'markdown';

    final requestBody = jsonEncode({
      'url': url,
      'format': format,
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/reader'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', format == 'markdown' ? 'text/markdown' : 'text/plain')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔阅读器请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      return McpToolResult(body);
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔阅读器失败: ${error is Exception ? error.toString() : '未知错误'}\n'
      'URL: ${args['url']}',
      isError: true,
    );
  }
}

Future<McpToolResult> _metasoChat(
  Map<String, Object?> args,
  String apiKey,
) async {
  try {
    final query = (args['q'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('查询问题 (q) 不能为空', isError: true);
    }
    final scope = (args['scope'] as String?) ?? 'webpage';
    final model = (args['model'] as String?) ?? 'fast';
    final conciseSnippet = args['conciseSnippet'] == true;

    final requestBody = jsonEncode({
      'model': model,
      'scope': scope,
      'stream': false,
      'format': 'chat_completions',
      'conciseSnippet': conciseSnippet,
      'messages': [
        {'role': 'user', 'content': query},
      ],
    });

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 60);
    try {
      final request = await client.postUrl(
        Uri.parse('https://metaso.cn/api/v1/chat/completions'),
      );
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Accept', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return McpToolResult(
          '秘塔问答请求失败 (HTTP ${response.statusCode}): $body',
          isError: true,
        );
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      if (choices.isEmpty) {
        return const McpToolResult('秘塔问答未返回结果', isError: true);
      }
      final firstChoice = choices[0] as Map<String, Object?>;
      final message = firstChoice['message'] as Map<String, Object?>?;
      final answer = (message?['content'] as String?) ?? '';
      final citations = (data['citations'] as List?) ?? [];

      final buf = StringBuffer();
      buf.writeln(answer);

      if (citations.isNotEmpty) {
        buf.writeln('\n\n---\n**引用来源**:\n');
        for (var i = 0; i < citations.length; i++) {
          final cite = citations[i];
          if (cite is! Map) continue;
          final title = cite['title'] ?? '来源 ${i + 1}';
          final link = cite['link'] ?? '';
          if (link.toString().isNotEmpty) {
            buf.writeln('${i + 1}. [$title]($link)');
          } else {
            buf.writeln('${i + 1}. $title');
          }
        }
      }

      return McpToolResult(buf.toString());
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      '秘塔问答失败: ${error is Exception ? error.toString() : '未知错误'}',
      isError: true,
    );
  }
}

// ── Grok Search (xAI Official API with search_parameters) ──────────────────

/// `@aether/grok-search` tool execution (`web_search`) — uses xAI's native
/// `search_parameters` in `/v1/chat/completions` for real-time web search.
/// Docs: https://docs.x.ai/developers/rest-api-reference/inference/chat
/// and: https://docs.x.ai/developers/tools/web-search
Future<McpToolResult> runGrokSearchTool(
  String toolName,
  Map<String, Object?> args, {
  Map<String, String>? env,
}) async {
  if (toolName != 'web_search') {
    return McpToolResult('未知的工具: $toolName', isError: true);
  }

  final apiKey = env?['XAI_API_KEY'] ?? env?['AI_API_KEY'] ?? '';
  final apiUrl = env?['XAI_API_URL'] ?? env?['AI_API_URL'] ?? 'https://api.x.ai';
  final modelId = env?['XAI_MODEL_ID'] ?? env?['AI_MODEL_ID'] ?? 'grok-3';

  if (apiKey.isEmpty) {
    return const McpToolResult(
      '未配置 xAI API Key。请在 MCP 服务器环境变量中配置：\n\n'
      '  XAI_API_KEY — xAI API 密钥（https://console.x.ai 获取）\n'
      '  XAI_MODEL_ID — 模型 ID（默认 grok-3，推荐 grok-4.3）\n'
      '  XAI_API_URL — API 地址（默认 https://api.x.ai）\n\n'
      '也可使用兼容变量名：AI_API_KEY / AI_MODEL_ID / AI_API_URL',
      isError: true,
    );
  }

  final query = (args['query'] as String?)?.trim() ?? '';
  if (query.isEmpty) {
    return const McpToolResult('搜索查询内容 (query) 不能为空', isError: true);
  }

  // Build search_parameters from tool args (xAI native feature)
  final searchMode = (args['mode'] as String?) ?? 'on';
  final searchParams = <String, Object?>{
    'mode': searchMode,
    'return_citations': true,
  };
  if (args['max_search_results'] != null) {
    searchParams['max_search_results'] = _asIntOr(args['max_search_results'], 10);
  }
  if (args['from_date'] is String) {
    searchParams['from_date'] = args['from_date'];
  }
  if (args['to_date'] is String) {
    searchParams['to_date'] = args['to_date'];
  }
  if (args['sources'] is List) {
    searchParams['sources'] = args['sources'];
  }

  final timeout = int.tryParse(env?['XAI_TIMEOUT'] ?? env?['AI_TIMEOUT'] ?? '60') ?? 60;

  try {
    // Build endpoint
    var endpoint = apiUrl;
    if (!endpoint.endsWith('/v1/chat/completions')) {
      if (endpoint.endsWith('/')) {
        endpoint += 'v1/chat/completions';
      } else {
        endpoint += '/v1/chat/completions';
      }
    }

    final requestBody = jsonEncode({
      'model': modelId,
      'search_parameters': searchParams,
      'messages': [
        {'role': 'user', 'content': query},
      ],
      'stream': false,
    });

    final client = HttpClient()
      ..connectionTimeout = Duration(seconds: timeout);
    try {
      final request = await client.postUrl(Uri.parse(endpoint));
      request.headers
        ..set('Content-Type', 'application/json')
        ..set('Authorization', 'Bearer $apiKey');
      request.write(requestBody);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        final hint = switch (response.statusCode) {
          401 => '认证失败，请检查 XAI_API_KEY 是否正确',
          403 => 'API 权限不足，请确认 Key 有搜索权限',
          429 => '请求过于频繁，请稍后重试',
          _ => 'xAI API 请求失败 (HTTP ${response.statusCode})',
        };
        return McpToolResult('$hint\n\n响应: $body', isError: true);
      }

      final data = jsonDecode(body) as Map<String, Object?>;
      final choices = (data['choices'] as List?) ?? [];
      if (choices.isEmpty) {
        return const McpToolResult('xAI 未返回搜索结果', isError: true);
      }

      final firstChoice = choices[0] as Map<String, Object?>;
      final message = firstChoice['message'] as Map<String, Object?>?;
      final content = (message?['content'] as String?) ?? '';

      // Extract citations if present
      final citations = (data['citations'] as List?) ?? [];

      final buf = StringBuffer();
      // Filter thinking blocks if present
      buf.write(_filterThinkingContent(content));

      if (citations.isNotEmpty) {
        buf.writeln('\n\n---\n**搜索引用来源**:\n');
        for (var i = 0; i < citations.length; i++) {
          final cite = citations[i];
          if (cite is String) {
            buf.writeln('${i + 1}. $cite');
          } else if (cite is Map) {
            final title = cite['title'] ?? '来源 ${i + 1}';
            final url = cite['url'] ?? cite['link'] ?? '';
            if (url.toString().isNotEmpty) {
              buf.writeln('${i + 1}. [$title]($url)');
            } else {
              buf.writeln('${i + 1}. $title');
            }
          }
        }
      }

      final result = buf.toString().trim();
      if (result.isEmpty) {
        return const McpToolResult('xAI 搜索未返回有效内容', isError: true);
      }
      return McpToolResult(result);
    } finally {
      client.close();
    }
  } catch (error) {
    return McpToolResult(
      'xAI 搜索失败: ${error is Exception ? error.toString() : '未知错误'}\n\n'
      '请确认配置：\n'
      '  XAI_API_KEY — xAI API 密钥\n'
      '  XAI_MODEL_ID — 当前: $modelId\n'
      '  XAI_API_URL — 当前: $apiUrl',
      isError: true,
    );
  }
}

/// Remove <think>/<thinking> blocks from AI response.
String _filterThinkingContent(String content) {
  var result = content.replaceAll(
    RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(
    RegExp(r'<thinking>[\s\S]*?</thinking>', caseSensitive: false),
    '',
  );
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return result.trim();
}
