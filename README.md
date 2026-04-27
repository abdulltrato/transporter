# Transporter

Plataforma digital de mobilidade para conectar clientes e taxistas de motorizada em tempo real, com foco em bairros e cidades com transporte informal.

Este repositório contém:
- `backend/`: API NestJS (Node.js + TypeScript) com autenticação, matching, subscrição, avaliação e realtime.
- `mobile/`: app Flutter com fluxo completo de acesso, mapa e corrida.

## Estado Atual do Projeto

Funcionalidades já implementadas:
- autenticação por OTP e login social (Google/Facebook);
- perfis de cliente e taxista;
- atualização de localização e busca de taxistas próximos;
- ciclo de corrida: solicitar, aceitar/rejeitar, iniciar, concluir e cancelar;
- matching por raio progressivo (`2km -> 5km -> 8km -> 12km`);
- subscrição de taxistas com pagamento M-Pesa/eMola e validação manual por agente;
- avaliação de taxistas por estrelas (1 a 5);
- canal realtime por WebSocket para mapa e corridas;
- modo móvel robusto para reduzir impacto de rede instável.

## Estrutura Atual (Pastas e Arquivos)

```text
.
├─ backend/
│  ├─ src/
│  │  ├─ auth/
│  │  ├─ common/
│  │  ├─ database/
│  │  ├─ drivers/
│  │  ├─ location/
│  │  ├─ ratings/
│  │  ├─ realtime/
│  │  ├─ redis/
│  │  ├─ rides/
│  │  ├─ subscriptions/
│  │  ├─ users/
│  │  ├─ app.module.ts
│  │  └─ main.ts
│  ├─ .env.example
│  ├─ package.json
│  ├─ tsconfig.json
│  └─ tsconfig.build.json
├─ mobile/
│  ├─ android/
│  ├─ ios/
│  ├─ lib/
│  │  ├─ core/
│  │  ├─ features/
│  │  │  ├─ auth/presentation/login_page.dart
│  │  │  ├─ map/presentation/map_page.dart
│  │  │  └─ ride/presentation/ride_page.dart
│  │  ├─ models/
│  │  ├─ services/
│  │  │  ├─ api_client.dart
│  │  │  ├─ auth_service.dart
│  │  │  ├─ device_location_service.dart
│  │  │  ├─ native_runtime_service.dart
│  │  │  ├─ realtime_map_service.dart
│  │  │  ├─ rides_service.dart
│  │  │  ├─ subscription_service.dart
│  │  │  ├─ agent_subscriptions_service.dart
│  │  │  └─ ratings_service.dart
│  │  └─ main.dart
│  ├─ test/widget_test.dart
│  ├─ analysis_options.yaml
│  └─ pubspec.yaml
├─ docker-compose.yml
├─ logo-transporter.png
├─ README.md
└─ transporter.md
```

## Execução Rápida Local

Pré-requisitos:
- Node.js 20+;
- Flutter 3.3+;
- PostgreSQL e Redis (locais ou Docker).

### 1) Infra (opcional com Docker)

```bash
docker compose up -d
```

Observação importante:
- `docker-compose.yml` expõe PostgreSQL em `localhost:5433`;
- se usar `DATABASE_URL`, ajuste para `postgres://postgres:postgres@localhost:5433/transporter`.

### 2) Backend

```bash
cd backend
cp .env.example .env
npm install
npm run typecheck
npm run build
npm run start:dev
```

API: `http://localhost:3000/api`

### 3) Mobile

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

Opcional (forçar API):

```bash
flutter run --dart-define=TRANSPORTER_API_BASE_URL=http://10.0.2.2:3000
```

## O Que Esta App Pode Resolver (Proposito Expandido)

Além de pedir corrida, uma aplicação deste tipo pode:
- reduzir tempo de espera do cliente em zonas com transporte informal;
- gerar rendimento previsível para taxistas com melhor distribuição de corridas;
- apoiar operação de cooperativas/associações com gestão de atividade;
- criar dados de mobilidade úteis para planeamento local;
- permitir serviços adicionais: entregas locais, rotas partilhadas, assinatura de condutor, reputação por avaliações.

## Melhorias Prioritárias

- criar testes de backend (atualmente não há suite automatizada de API);
- aumentar testes móveis além do `widget_test.dart` base;
- adicionar CI em `.github/workflows`;
- introduzir migrações versionadas (evitar depender apenas de bootstrap de schema);
- restringir CORS por ambiente e desligar `OTP_DEV_MODE` fora de desenvolvimento;
- adicionar observabilidade (métricas, tracing, alertas);
- implementar notificações push para novas corridas e mudanças de estado.

## Fragilidades Principais e Solucoes

1. Rede móvel instável e app em background.
Solução: manter e evoluir o modo robusto com fila local, backoff, confirmação de entrega e replay idempotente.

2. Fraude de localização.
Solução: validar consistência de velocidade/percurso, detetar spoofing e cruzar sinais de integridade do dispositivo.

3. Validação manual de pagamentos pode atrasar ativação.
Solução: webhook e reconciliação automática para M-Pesa/eMola com auditoria.

4. Crescimento de utilizadores aumenta custo de realtime.
Solução: separar canal de eventos por região, usar Redis Pub/Sub e escalar horizontalmente gateways.

5. Cobertura de testes insuficiente.
Solução: pirâmide de testes com unit, integração e E2E (auth, location, rides, subscriptions, ratings).

## Documentação

- `README.md` (este ficheiro): visão geral, execução e prioridades.
- `transporter.md`: documento técnico completo (arquitetura, endpoints, modelo de dados, riscos e roadmap).
