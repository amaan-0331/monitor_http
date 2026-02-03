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
    final captured = await _captureRequest(request);
    final id = Monitor.startRequest(
      method: captured.request.method,
      uri: captured.request.url,
      headers: captured.request.headers,
      body: _maybeDecodeBody(captured.bodyBytes, captured.request.headers),
      bodyBytes: captured.bodyBytes.length,
      bodyRawBytes: captured.bodyBytes,
    );

    try {
      final response = await _inner.send(captured.request);
      final responseBytes = await response.stream.toBytes();
      final responseBody = _maybeDecodeBody(responseBytes, response.headers);

      Monitor.completeRequest(
        id: id,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: responseBody,
        responseSize: responseBytes.length,
      );

      return http.StreamedResponse(
        http.ByteStream.fromBytes(responseBytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        contentLength: responseBytes.length,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        request: response.request,
      );
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

class _CapturedRequest {
  _CapturedRequest({required this.request, required this.bodyBytes});

  final http.StreamedRequest request;
  final Uint8List bodyBytes;
}

Future<_CapturedRequest> _captureRequest(http.BaseRequest request) async {
  final stream = request.finalize();
  final bodyBytes = await stream.toBytes();

  final streamed = http.StreamedRequest(request.method, request.url)
    ..followRedirects = request.followRedirects
    ..maxRedirects = request.maxRedirects
    ..persistentConnection = request.persistentConnection
    ..headers.addAll(request.headers);

  if (request.contentLength != null && request.contentLength! >= 0) {
    streamed.contentLength = request.contentLength;
  } else if (bodyBytes.isNotEmpty) {
    streamed.contentLength = bodyBytes.length;
  }

  if (bodyBytes.isNotEmpty) {
    streamed.sink.add(bodyBytes);
  }
  await streamed.sink.close();

  return _CapturedRequest(request: streamed, bodyBytes: bodyBytes);
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
