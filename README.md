# Transporter

Plataforma digital de mobilidade para ligar clientes e taxistas de motorizada em tempo real, com foco em bairros e cidades com transporte informal.

Este repositório contém:
- `backend/`: API NestJS (Node.js + TypeScript) com autenticação, matching, subscrição, avaliação e realtime.
- `mobile/`: app Flutter com fluxo completo de acesso, mapa e corrida.

## Estado Atual do Projeto

Funcionalidades já implementadas:
- autenticação por OTP e login social (Google/Facebook);
- perfis de cliente e taxista;
- atualização de localização e procura de taxistas próximos;
- ciclo de corrida: solicitar, aceitar/rejeitar, iniciar, concluir e cancelar;
- matching por raio progressivo (`2km -> 5km -> 8km -> 12km`);
- subscrição de taxistas com pagamento M-Pesa/eMola e validação manual por agente;
- avaliação de taxistas por estrelas (1 a 5);
- canal em tempo real por WebSocket para mapa e corridas;
- modo móvel robusto para reduzir impacto de rede instável.

## Política de Avaliação, Priorização e Brindes

Regras recomendadas para operação:
- quanto melhor a avaliação do taxista, maior a prioridade no matching;
- avaliações baixas reduzem a frequência de atribuição automática;
- avaliações muito baixas retiram o taxista da atribuição automática até concluir plano de melhoria.

Faixas sugeridas de priorização:
- `4.8 - 5.0`: prioridade máxima e maior frequência de pedidos;
- `4.5 - 4.79`: prioridade elevada;
- `4.0 - 4.49`: prioridade normal;
- `3.5 - 3.99`: prioridade reduzida;
- `< 3.5`: sem atribuição automática temporária, com revisão de qualidade.

Condições de justiça operacional:
- aplicar peso da avaliação apenas após amostra mínima (ex.: 20 avaliações);
- usar janela móvel (ex.: últimas 100 corridas) para evitar penalização perpétua;
- combinar avaliação com taxa de cancelamento, taxa de aceitação e pontualidade.

Brindes e incentivos possíveis:
- bónus semanal por desempenho;
- redução de comissão/plano para taxistas de excelência;
- destaque na listagem e em zonas de maior procura;
- vouchers de combustível, manutenção e dados móveis;
- acesso antecipado a funcionalidades premium;
- suporte prioritário e selo de “Taxista de Confiança”.
- cupões de desconto para clientes frequentes;
- cashback em campanhas de referência (“indique e ganhe”);
- upgrades sazonais (ex.: prioridade em horas de pico para clientes fidelizados).

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

## Contrato de API (Resumo Indispensável)

Base:
- REST: `http://localhost:3000/api`
- WebSocket: `ws://localhost:3000/realtime`

Autenticação:
- header padrão: `Authorization: Bearer <accessToken>`
- exceções públicas: `POST /auth/request-otp`, `POST /auth/verify-otp`, `POST /auth/social`, `GET /subscriptions/agent/pending`, `PATCH /subscriptions/agent/:subscriptionId/validate`, `GET /ratings/drivers/:driverId/summary`

Formato de erro (NestJS):

```json
{
  "statusCode": 400,
  "message": "descrição do erro",
  "error": "Bad Request"
}
```

Módulos de API:
- `auth`: OTP e login social.
- `users` e `drivers`: perfil e estado do taxista.
- `location`: update e consulta de proximidade.
- `rides`: ciclo de vida da corrida.
- `subscriptions`: pagamento e validação de subscrição.
- `ratings`: avaliação e resumo de reputação.
- `realtime`: atualização em tempo real de mapa e corrida.

## Matriz de Ambientes (Dev, Staging, Prod)

| Variável | Dev | Staging | Prod | Observação |
|---|---|---|---|---|
| `PORT` | `3000` | `3000` | `3000` | opcional no backend, default em `main.ts` |
| `JWT_SECRET` | valor local forte | secret do ambiente | secret do ambiente | nunca versionar |
| `JWT_EXPIRES_IN` | `7d` | `1d` ou `12h` | `15m` a `1h` | combinar com refresh-token futuro |
| `OTP_DEV_MODE` | `true` | `false` | `false` | em prod nunca deve retornar `devCode` |
| `OTP_TTL_SECONDS` | `300` | `300` | `180` a `300` | janela de validade do OTP |
| `OTP_REQUEST_COOLDOWN_SECONDS` | `30` | `30` | `45` a `60` | anti-spam |
| `OTP_REQUEST_WINDOW_SECONDS` | `300` | `300` | `600` | janela de rate limit |
| `OTP_MAX_REQUESTS_PER_WINDOW` | `5` | `5` | `3` a `5` | risco de brute force |
| `AGENT_VALIDATION_KEY` | chave local | chave por ambiente | chave forte + rotação | usada em endpoints de agente |
| `DATABASE_URL` | local | staging DB | prod DB | preferível ao bloco `POSTGRES_*` |
| `REDIS_URL` | local | staging Redis | prod Redis | preferível ao bloco `REDIS_*` |
| `LOCATION_TTL_SECONDS` | `1800` | `900` a `1800` | `300` a `900` | define expurgo de localização |

Notas:
- se usar `docker-compose.yml` local, PostgreSQL fica em `localhost:5433`.
- o `.env.example` ainda usa `5432`; ajustar no `.env` local.

## Runbook de Deploy e Rollback (Mínimo)

Deploy:
1. garantir `git pull` atualizado e sem alterações pendentes.
2. validar backend com `npm run typecheck` e `npm run build`.
3. validar mobile com `flutter analyze` e `flutter test`.
4. aplicar variáveis do ambiente alvo (`staging` ou `prod`).
5. publicar backend e executar smoke test:
`/api/auth/request-otp`, `/api/location/drivers/nearby`, `WS /realtime`.
6. publicar mobile apontando para API do ambiente alvo.

Rollback:
1. reverter para a versão anterior estável (tag anterior).
2. restaurar configurações/env anteriores.
3. executar smoke test dos endpoints críticos.
4. abrir incidente com causa, impacto e plano de prevenção.

## Qualidade Obrigatória (CI)

Antes de merge para branch principal:
- backend: `npm run typecheck` e `npm run build` obrigatórios;
- mobile: `flutter analyze` e `flutter test` obrigatórios;
- nenhum segredo em texto plano no diff;
- atualizar documentação quando houver mudança de API/ambiente.

Meta mínima de evolução:
- adicionar testes de integração backend para `auth`, `rides`, `subscriptions`;
- aumentar testes de widget/integration no mobile;
- bloquear merge sem pipeline verde.

## Processo de Release

Modelo recomendado:
1. branch `main` protegida.
2. desenvolvimento por `feature/*`.
3. merge via PR com revisão técnica.
4. tags semânticas: `vMAJOR.MINOR.PATCH`.
5. changelog por release com:
   - funcionalidades;
   - correções;
   - breaking changes;
   - passos de migração, quando aplicável.

## O Que Esta Aplicação Pode Resolver (Propósito Expandido)

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

## Fragilidades Principais e Soluções

1. Rede móvel instável e app em background.
Solução: manter e evoluir o modo robusto com fila local, backoff, confirmação de entrega e replay idempotente.

2. Fraude de localização.
Solução: validar consistência de velocidade/percurso, detetar spoofing e cruzar sinais de integridade do dispositivo.

3. Validação manual de pagamentos pode atrasar ativação.
Solução: webhook e reconciliação automática para M-Pesa/eMola com auditoria.

4. Crescimento de utilizadores aumenta o custo de operação em tempo real.
Solução: separar canal de eventos por região, usar Redis Pub/Sub e escalar horizontalmente gateways.

5. Cobertura de testes insuficiente.
Solução: pirâmide de testes com unit, integração e E2E (auth, location, rides, subscriptions, ratings).

## Documentação

- `README.md` (este ficheiro): visão geral, execução e prioridades.
- `transporter.md`: documento técnico completo (arquitetura, endpoints, modelo de dados, riscos e roadmap).



