import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Cliente HTTP simples para o MVP.
///
/// Mantém o contrato explícito e lança `HttpException` com mensagens legíveis
/// para a UI quando a API devolve erros.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.token,
    this.requestTimeout = const Duration(seconds: 12),
  });

  final String baseUrl;
  final Duration requestTimeout;
  String? token;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
    final request = await HttpClient().getUrl(uri);
    _setDefaultHeaders(request, headers: headers);

    final response = await _closeWithTimeout(request, uri);
    return _decodeResponse(response, uri);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().postUrl(uri);
    _setDefaultHeaders(request, headers: headers);

    request.write(jsonEncode(body));
    final response = await _closeWithTimeout(request, uri);
    return _decodeResponse(response, uri);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().patchUrl(uri);
    _setDefaultHeaders(request, headers: headers);

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await _closeWithTimeout(request, uri);
    return _decodeResponse(response, uri);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().putUrl(uri);
    _setDefaultHeaders(request, headers: headers);

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await _closeWithTimeout(request, uri);
    return _decodeResponse(response, uri);
  }

  void _setDefaultHeaders(
    HttpClientRequest request, {
    Map<String, String>? headers,
  }) {
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    final authToken = token;
    if (authToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
    }

    if (headers != null) {
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }
  }

  Future<HttpClientResponse> _closeWithTimeout(
    HttpClientRequest request,
    Uri uri,
  ) async {
    try {
      return await request.close().timeout(requestTimeout);
    } on TimeoutException {
      throw HttpException(
        'Tempo limite excedido ao comunicar com o servidor.',
        uri: uri,
      );
    }
  }

  Future<dynamic> _decodeResponse(HttpClientResponse response, Uri uri) async {
    final payload = await response.transform(utf8.decoder).join();
    final body = payload.isEmpty ? <String, dynamic>{} : jsonDecode(payload);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map<String, dynamic>) {
      final message = body['message'];

      if (message is String) {
        throw HttpException(message, uri: uri);
      }

      if (message is List) {
        throw HttpException(message.join(', '), uri: uri);
      }
    }

    throw HttpException(
      'Request failed with status ${response.statusCode}',
      uri: uri,
    );
  }
}
