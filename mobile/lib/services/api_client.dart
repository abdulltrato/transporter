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
    final payload = await response.transform(utf8.decoder).join();
    return payload.isEmpty ? <String, dynamic>{} : jsonDecode(payload);
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
    final payload = await response.transform(utf8.decoder).join();

    return payload.isEmpty ? <String, dynamic>{} : jsonDecode(payload);
  }
}
