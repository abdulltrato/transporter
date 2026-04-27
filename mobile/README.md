# Transporter Mobile

Aplicação Flutter do Transporter para ligação entre clientes e taxistas em tempo real.

## Objetivos desta versão

- Manter uma interface simples e fácil de usar.
- Oferecer autenticação por OTP para cliente/taxista.
- Oferecer autenticação por OTP ou conta social (Google/Facebook).
- Mostrar taxistas próximos com atualização em tempo real.
- Gerir ciclo de vida completo da corrida.
- Ativar um **modo nativo robusto** para resiliência em redes instáveis.
- Permitir subscrição do mototaxista por plano (mensal, trimestral, semestral, anual) com pagamento M-Pesa/eMola e validação manual.
- Permitir avaliação de taxistas em estrelas (1 a 5) após corrida concluída.

## Fluxo da interface

O shell principal mantém 3 separadores fixos:

1. `Acesso`: login OTP, seleção de perfil e controlo do modo nativo robusto.
2. `Mapa`: estado da ligação realtime e lista de taxistas por proximidade.
3. `Corrida`: ações de solicitação, aceitação, início, conclusão e histórico.

## Modo Nativo Robusto

O modo nativo robusto está ativo por defeito e pode ser desligado no ecrã `Acesso`.

Quando ativo:

- Guarda a última localização pendente para evitar perda de sincronização.
- Faz retentativas automáticas com backoff exponencial.
- Pausa sincronizações em segundo plano e retoma em foreground.
- Mostra estado operacional no rodapé global da aplicação.

Documentação técnica completa:

- `docs/modo_nativo_robusto.md`

## Estrutura relevante

```text
lib/
  core/
    app_colors.dart
    app_theme.dart
  features/
    auth/presentation/login_page.dart
    map/presentation/map_page.dart
    ride/presentation/ride_page.dart
  models/
  services/
    native_runtime_service.dart
    realtime_map_service.dart
  main.dart
```

## Execução local

```bash
flutter pub get
flutter run
```

Opcional: definir API explícita em runtime.

```bash
flutter run --dart-define=TRANSPORTER_API_BASE_URL=http://10.0.2.2:3000
```

## Observações

- O projeto está preparado para testes automáticos, mas os testes de ambiente Flutter podem ser executados mais tarde, conforme combinado.
- A API base mantém fallback automático para Android Emulator (`10.0.2.2`) e localhost nos restantes ambientes.
