import 'dart:convert';
import 'dart:io';

class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map(
        (key, value) => MapEntry(key, value.toString())
      )
    );
    final request = await HttpClient().getUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    final response = await request.close();
    return _decodeResponse(response, uri);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    request.write(jsonEncode(body));
    final response = await request.close();
    return _decodeResponse(response, uri);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().patchUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    return _decodeResponse(response, uri);
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = await HttpClient().putUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (body != null) {
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    return _decodeResponse(response, uri);
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
      uri: uri
    );
  }
}
