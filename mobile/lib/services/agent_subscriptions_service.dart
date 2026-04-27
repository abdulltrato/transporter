import '../models/driver_subscription.dart';
import 'api_client.dart';

class AgentSubscriptionsService {
  AgentSubscriptionsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DriverSubscription>> listPending({
    required String agentKey,
  }) async {
    final response = await _apiClient.get(
      '/api/subscriptions/agent/pending',
      headers: {'x-agent-key': agentKey},
    );

    if (response is! List<dynamic>) {
      return [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(DriverSubscription.fromJson)
        .toList();
  }

  Future<DriverSubscription> validate({
    required String agentKey,
    required String subscriptionId,
    required String action,
    required String agentName,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'action': action,
      'agentName': agentName,
    };
    final normalizedNotes = notes?.trim() ?? '';
    if (normalizedNotes.isNotEmpty) {
      payload['notes'] = normalizedNotes;
    }

    final response = await _apiClient.patch(
      '/api/subscriptions/agent/$subscriptionId/validate',
      body: payload,
      headers: {'x-agent-key': agentKey},
    );

    final map = _asJsonMap(response);
    if (map == null) {
      throw Exception('Resposta inválida ao validar subscrição.');
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
