import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'network_store.dart';

/// A [Dio] [Interceptor] that records every request/response into the
/// [NetworkStore] so the Network panel shows live traffic — the Dio analogue of
/// the web's `EnhancedNetworkService` fetch/XHR shims.
///
/// Add it to any Dio built through `buildAppDio()` (the app's收口 factory). It is
/// observe-only: it never alters requests, and for streaming responses it tees
/// the byte stream so the panel captures each SSE/LLM chunk while the original
/// consumer still receives the bytes untouched.
///
/// Headers are recorded verbatim (no redaction) so the Network panel behaves like
/// a real browser devtools — cURL export / replay work out of the box. This is a
/// local, open-source developer tool; don't paste exports into public channels.
class DioDevInterceptor extends Interceptor {
  DioDevInterceptor();

  /// Where the per-request store id is stashed on [RequestOptions.extra] so the
  /// response/error callbacks can correlate back to the entry they started.
  static const String _idKey = '__devtools_net_id';

  final NetworkStore _store = NetworkStore.instance;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final payload = _serializeBody(options.data);
    final id = _store.start(
      method: options.method,
      url: options.uri.toString(),
      requestHeaders: _headers(options.headers),
      requestPayload: payload,
      requestSize: payload == null ? null : utf8.encode(payload).length,
    );
    options.extra[_idKey] = id;
    // A CancelToken abort (e.g. user stops generation) never reaches onError for
    // an already-streaming response, so flip the entry directly when it fires.
    options.cancelToken?.whenCancel.then((_) => _store.markCancelled(id));
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final id = response.requestOptions.extra[_idKey];
    if (id is! int) {
      handler.next(response);
      return;
    }

    final data = response.data;
    if (data is ResponseBody) {
      // Streaming response: tee the byte stream so we capture each chunk while
      // the original consumer reads the same bytes.
      _store.beginStream(
        id,
        statusCode: response.statusCode ?? data.statusCode,
        statusText: response.statusMessage,
        headers: _responseHeaders(response.headers),
      );
      response.data = ResponseBody(
        _captureStream(id, data.stream),
        data.statusCode,
        headers: data.headers,
        statusMessage: data.statusMessage,
        isRedirect: data.isRedirect,
        redirects: data.redirects,
      );
      handler.next(response);
      return;
    }

    final body = _serializeBody(data);
    _store.completeResponse(
      id,
      statusCode: response.statusCode ?? 0,
      statusText: response.statusMessage,
      headers: _responseHeaders(response.headers),
      body: body,
      size: body == null ? null : utf8.encode(body).length,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final id = err.requestOptions.extra[_idKey];
    if (id is! int) {
      handler.next(err);
      return;
    }
    final cancelled = err.type == DioExceptionType.cancel;
    final res = err.response;
    final body = res == null ? null : _serializeBody(res.data);
    _store.completeError(
      id,
      message: err.message ?? err.toString(),
      stack: err.stackTrace.toString(),
      statusCode: res?.statusCode,
      statusText: res?.statusMessage,
      headers: res == null
          ? const <String, String>{}
          : _responseHeaders(res.headers),
      body: body,
      cancelled: cancelled,
    );
    handler.next(err);
  }

  /// Wraps [source] so each chunk is appended to the store entry as it flows to
  /// the real consumer, sealing the entry when the stream ends/errors.
  Stream<Uint8List> _captureStream(int id, Stream<Uint8List> source) {
    // A stateful UTF-8 decoder so a multi-byte character split across two chunks
    // (very common in SSE / LLM token streams) decodes correctly instead of
    // emitting `�` at the seam. Decoding each chunk independently (the previous
    // behaviour) corrupted the captured body for non-ASCII (e.g. Chinese) text.
    final decoder = _Utf8StreamDecoder();
    return source.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleData: (data, sink) {
          _store.appendStream(id, data, decoder.add(data));
          sink.add(data);
        },
        handleError: (error, stack, sink) {
          final tail = decoder.close();
          if (tail.isNotEmpty) _store.appendStream(id, const <int>[], tail);
          final cancelled =
              error is DioException && error.type == DioExceptionType.cancel;
          _store.endStream(id, cancelled: cancelled);
          sink.addError(error, stack);
        },
        handleDone: (sink) {
          final tail = decoder.close();
          if (tail.isNotEmpty) _store.appendStream(id, const <int>[], tail);
          _store.endStream(id);
          sink.close();
        },
      ),
    );
  }

  // --- serialization ----------------------------------------------------------

  // Headers are captured verbatim (no redaction): this is a local, open-source
  // developer tool — like Chrome DevTools' network panel it shows full headers so
  // cURL export / replay actually work. Don't paste exports somewhere public.

  Map<String, String> _headers(Map<String, dynamic> headers) {
    final out = <String, String>{};
    headers.forEach((key, value) {
      out[key] = value is Iterable ? value.join(', ') : '$value';
    });
    return out;
  }

  Map<String, String> _responseHeaders(Headers headers) {
    final out = <String, String>{};
    headers.map.forEach((key, values) {
      out[key] = values.join(', ');
    });
    return out;
  }

  static String? _serializeBody(Object? data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is FormData) {
      final parts = <String>[
        for (final f in data.fields) '${f.key}=${f.value}',
        for (final f in data.files) '[File: ${f.value.filename ?? 'binary'}]',
      ];
      return parts.join('\n');
    }
    if (data is List<int>) return '[Binary Data: ${data.length} bytes]';
    if (data is Stream) return '[Stream]';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

/// Wraps Dart's chunked UTF-8 decoder so bytes spanning chunk boundaries decode
/// correctly: [add] returns only the text decodable from the bytes seen so far,
/// holding back any incomplete trailing multi-byte sequence until the next chunk
/// (or [close], which flushes the remainder with replacement chars).
class _Utf8StreamDecoder {
  final List<String> _out = <String>[];
  late final Sink<List<int>> _sink = const Utf8Decoder(allowMalformed: true)
      .startChunkedConversion(_CallbackSink<String>(_out.add));

  String add(List<int> bytes) {
    _out.clear();
    _sink.add(bytes);
    return _out.join();
  }

  String close() {
    _out.clear();
    _sink.close();
    return _out.join();
  }
}

/// A minimal [Sink] that forwards each added value to a callback (used to drain
/// the chunked UTF-8 decoder's decoded strings).
class _CallbackSink<T> implements Sink<T> {
  _CallbackSink(this._onData);

  final void Function(T) _onData;

  @override
  void add(T data) => _onData(data);

  @override
  void close() {}
}
