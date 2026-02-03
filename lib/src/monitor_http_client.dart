import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:monitor/monitor.dart';

/// Creates a [http.Client] that logs requests and responses via Monitor.
http.Client createMonitorClient({http.Client? inner}) {
  return MonitorHttpClient(inner: inner);
}

/// A [http.Client] wrapper that automatically tracks HTTP activity with Monitor.
class MonitorHttpClient extends http.BaseClient {
  MonitorHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final config = Monitor.config;
    final logRequestBody = config.logRequestBody;

    Uint8List? requestBodyBytes;
    String? requestBody;
    int? requestSize;

    if (request is http.Request) {
      if (logRequestBody) {
        final bytes = Uint8List.fromList(request.bodyBytes);
        requestSize = bytes.length;
        if (bytes.isNotEmpty) {
          requestBodyBytes = bytes;
          requestBody = _maybeDecodeBody(bytes, request.headers);
        }
      } else {
        requestSize = request.contentLength;
      }
    } else if (request.contentLength != null && request.contentLength! >= 0) {
      requestSize = request.contentLength;
    }

    final id = Monitor.startRequest(
      method: request.method,
      uri: request.url,
      headers: request.headers,
      body: requestBody,
      bodyBytes: requestSize,
      bodyRawBytes: requestBodyBytes,
    );

    try {
      final response = await _inner.send(request);
      return _wrapResponse(response, id);
    } catch (error) {
      Monitor.failRequest(
        id: id,
        errorMessage: error.toString(),
        isTimeout: error is TimeoutException,
      );
      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

http.StreamedResponse _wrapResponse(
  http.StreamedResponse response,
  String requestId,
) {
  final captureBody = Monitor.config.logResponseBody;
  final accumulator = _ResponseAccumulator(captureBody: captureBody);
  var completed = false;

  void completeSuccess() {
    if (completed) return;
    completed = true;
    final responseBytes = accumulator.takeBytes();
    final responseBody = captureBody
        ? _maybeDecodeBody(responseBytes, response.headers)
        : null;

    Monitor.completeRequest(
      id: requestId,
      statusCode: response.statusCode,
      responseHeaders: response.headers,
      responseBody: responseBody,
      responseSize: accumulator.size,
    );
  }

  void completeError(Object error) {
    if (completed) return;
    completed = true;
    Monitor.failRequest(
      id: requestId,
      errorMessage: error.toString(),
      isTimeout: error is TimeoutException,
    );
  }

  final tappedStream = _tapStream(
    response.stream,
    onData: accumulator.add,
    onError: (error, _) => completeError(error),
    onDone: completeSuccess,
  );

  return http.StreamedResponse(
    http.ByteStream(tappedStream),
    response.statusCode,
    headers: response.headers,
    reasonPhrase: response.reasonPhrase,
    contentLength: response.contentLength,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    request: response.request,
  );
}

class _ResponseAccumulator {
  _ResponseAccumulator({required this.captureBody})
    : _builder = captureBody ? BytesBuilder(copy: false) : null;

  final bool captureBody;
  final BytesBuilder? _builder;
  var _size = 0;

  void add(List<int> chunk) {
    _size += chunk.length;
    _builder?.add(chunk);
  }

  int get size => _size;

  Uint8List takeBytes() {
    if (_builder == null) return Uint8List(0);
    return _builder.takeBytes();
  }
}

Stream<List<int>> _tapStream(
  Stream<List<int>> source, {
  required void Function(List<int>) onData,
  required void Function(Object, StackTrace) onError,
  required void Function() onDone,
}) {
  late StreamSubscription<List<int>> subscription;
  late final StreamController<List<int>> controller;
  controller = StreamController<List<int>>(
    sync: true,
    onListen: () {
      subscription = source.listen(
        (data) {
          onData(data);
          controller.add(data);
        },
        onError: (Object error, StackTrace stackTrace) {
          onError(error, stackTrace);
          controller.addError(error, stackTrace);
        },
        onDone: () {
          onDone();
          controller.close();
        },
        cancelOnError: false,
      );
    },
    onPause: () => subscription.pause(),
    onResume: () => subscription.resume(),
    onCancel: () => subscription.cancel(),
  );

  return controller.stream;
}

String? _maybeDecodeBody(Uint8List bytes, Map<String, String> headers) {
  if (bytes.isEmpty) return null;
  final contentType = _headerValue(headers, 'content-type');
  if (!_isTextualContentType(contentType)) return null;

  return utf8.decode(bytes, allowMalformed: true);
}

bool _isTextualContentType(String? contentType) {
  if (contentType == null) return false;
  final lower = contentType.toLowerCase();
  if (lower.startsWith('multipart/')) return false;
  if (lower.startsWith('text/')) return true;

  return lower.contains('json') ||
      lower.contains('xml') ||
      lower.contains('x-www-form-urlencoded') ||
      lower.contains('graphql') ||
      lower.contains('javascript') ||
      lower.contains('yaml');
}

String? _headerValue(Map<String, String> headers, String name) {
  final target = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == target) {
      return entry.value;
    }
  }
  return null;
}
