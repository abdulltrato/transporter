import '../models/driver_subscription.dart';
import 'api_client.dart';

class SubscriptionService {
  SubscriptionService(this._apiClient);

  final ApiClient _apiClient;

  Future<DriverSubscription?> loadMyCurrentSubscription() async {
    final response = await _apiClient.get('/api/subscriptions/me/current');
    if (response == null) {
      return null;
    }

    final payload = _asJsonMap(response);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    return DriverSubscription.fromJson(payload);
  }

  Future<List<DriverSubscription>> listMySubscriptions() async {
    final response = await _apiClient.get('/api/subscriptions/me/history');
    if (response is! List<dynamic>) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(DriverSubscription.fromJson)
        .toList();
  }

  Future<DriverSubscription> requestPayment({
    required String plan,
    required String paymentMethod,
    required String paymentReference,
    String? paymentNotes,
  }) async {
    final payload = <String, dynamic>{
      'plan': plan,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
    };

    final normalizedNotes = paymentNotes?.trim() ?? '';
    if (normalizedNotes.isNotEmpty) {
      payload['paymentNotes'] = normalizedNotes;
    }

    final response = await _apiClient.post('/api/subscriptions/me/payment', payload);
    final map = _asJsonMap(response);
    if (map == null) {
      throw Exception('Resposta inválida ao registar pagamento.');
    }

    return DriverSubscription.fromJson(map);
  }
}

Map<String, dynamic>? _asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  return null;
}
