# Modo Nativo Robusto

## Finalidade

O modo nativo robusto existe para manter a experiência estável quando:

- a ligação de dados oscila;
- a app vai para segundo plano;
- o backend demora a responder.

## Componentes principais

### `NativeRuntimeService`

Ficheiro: `lib/services/native_runtime_service.dart`

Responsabilidades:

- gerir modo `standard` e `robust`;
- receber pedidos de sincronização de localização;
- manter uma fila coalescida (última localização vence);
- aplicar retentativas com backoff exponencial;
- expor snapshots de estado para a UI.

### Integração no `main.dart`

- Observa ciclo de vida (`WidgetsBindingObserver`).
- Pausa/retoma sincronização consoante foreground/background.
- Mostra estado do modo no rodapé global da aplicação.
- Permite alternar modo robusto no ecrã de acesso.

### `RealtimeMapService` robustecido

Ficheiro: `lib/services/realtime_map_service.dart`

Melhorias:

- reconexão automática com limite de tentativas;
- delays progressivos entre tentativas;
- corte de loops em falha de autenticação (`auth:error`);
- emissão de mensagens legíveis para feedback na interface.

## Estados expostos

O snapshot operativo (`NativeRuntimeSnapshot`) fornece:

- modo ativo (`Padrão` ou `Nativo robusto`);
- estado (`Em espera`, `A sincronizar`, `Em retentativa`, `Pausado em segundo plano`);
- número de tentativas;
- existência de sessão autenticada;
- erro mais recente (quando aplicável).

## Estratégia de fallback

Se o modo robusto for desativado:

- o envio de localização continua funcional;
- deixam de existir retentativas automáticas com backoff;
- o comportamento fica mais direto, útil para diagnóstico.
