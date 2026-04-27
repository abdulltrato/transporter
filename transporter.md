# Transporter - Documento Técnico Consolidado

## 1. Visão Geral

O Transporter é uma plataforma de mobilidade para ligar clientes e taxistas de motorizada com base em geolocalização e operação em tempo real.

Contexto do produto:
- foco em cenários de transporte urbano informal;
- necessidade de resposta rápida com internet instável;
- importância de fiabilidade operacional e segurança básica desde o MVP.

Estado atual:
- backend funcional em NestJS com API e WebSocket;
- app Flutter funcional com três áreas principais: acesso, mapa e corrida;
- suporte a subscrição do taxista e avaliação de serviço.

## 2. Propósitos de Uma App Como Esta

Uma app deste tipo deve ir além de "pedir motorizada":
- reduzir tempo de espera e incerteza do cliente;
- organizar oferta de taxistas por proximidade e disponibilidade real;
- melhorar o rendimento do taxista por distribuição mais justa de corridas;
- registar histórico de operação para auditoria e melhoria contínua;
- suportar camada financeira (subscrição, pagamentos e, mais tarde, repasses);
- criar base para serviços derivados: entregas, corridas programadas, clientes corporativos.

## 3. Arquitetura Atual do Repositório

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
│  └─ tsconfig*.json
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
│  │  └─ main.dart
│  ├─ test/widget_test.dart
│  ├─ analysis_options.yaml
│  └─ pubspec.yaml
├─ docker-compose.yml
├─ README.md
└─ transporter.md
```

## 4. Backend - Módulos e Responsabilidades

Módulos atuais em `backend/src`:
- `auth`: OTP, token JWT, login social e controlo de identidade.
- `users`: perfil base do utilizador.
- `drivers`: perfil operacional do taxista e estado online/offline.
- `location`: escrita e consulta de localização.
- `rides`: ciclo de vida de corrida e reatribuição.
- `subscriptions`: planos, pagamento e validação por agente.
- `ratings`: avaliação de taxista e resumo por estrelas.
- `realtime`: gateway WebSocket e emissão de eventos.
- `database`: conexão PostgreSQL e bootstrap de schema.
- `redis`: conexão Redis.
- `common`: enums, decorators, guardas, interfaces e utilitários.

Pontos técnicos já aplicados:
- validação global com `ValidationPipe` (`whitelist`, `forbidNonWhitelisted`, `transform`);
- prefixo global `/api`;
- guard global de autenticação com exceção de rotas públicas;
- matching por distância com raio progressivo;
- índice geoespacial Redis com `GEOSEARCH`.

## 5. Mobile - Estrutura e Comportamento Atual

Estrutura atual em `mobile/lib`:
- `core/`: tema e identidade visual.
- `features/auth/presentation`: login OTP/social, role e comandos de sessão.
- `features/map/presentation`: estado em tempo real e lista de taxistas próximos.
- `features/ride/presentation`: orquestração da corrida (solicitar, responder, iniciar, concluir, cancelar), subscrição e avaliação.
- `models/`: tipos de domínio.
- `services/`: cliente HTTP, sessão, localização, realtime, subscrição e avaliação.

### Modo Nativo Robusto (já integrado)

Objetivo:
- reduzir perda de sincronização em rede instável e durante transições de lifecycle.

Implementação atual:
- `NativeRuntimeService` com fila coalescida de localização;
- retentativas com backoff exponencial;
- pausa em background e retoma em foreground;
- snapshot de estado exposto para UI;
- `RealtimeMapService` com reconexão progressiva e tratamento de `auth:error`.

## 6. Fluxos Funcionais Implementados

1. Onboarding e autenticação.
- OTP por telefone (`request-otp`, `verify-otp`).
- login social (`social`) com vinculação de identidade.

2. Operação do taxista.
- completar perfil.
- manter estado online/offline.
- atualizar localização.
- manter subscrição ativa.

3. Operação do cliente.
- atualizar localização.
- ver taxistas próximos.
- solicitar corrida.

4. Ciclo de corrida.
- criação de pedido.
- atribuição inicial por proximidade.
- aceite/rejeição do taxista.
- reatribuição automática após rejeição.
- início, conclusão e cancelamento.

5. Qualidade do serviço.
- avaliação 1..5 após corrida concluída.
- consulta de resumo por taxista.

### 6.1 Política de reputação com impacto no matching

Princípio operacional:
- taxistas com melhor avaliação devem receber mais pedidos;
- taxistas com avaliação baixa devem ser progressivamente despriorizados;
- taxistas com avaliação muito baixa não devem receber atribuição automática.

Faixas recomendadas de priorização:
- `4.8 - 5.0`: prioridade máxima (`multiplicador 1.30`);
- `4.5 - 4.79`: prioridade elevada (`multiplicador 1.15`);
- `4.0 - 4.49`: prioridade normal (`multiplicador 1.00`);
- `3.5 - 3.99`: prioridade reduzida (`multiplicador 0.70`);
- `< 3.5`: sem atribuição automática até recuperação.

Condições para aplicar o peso de avaliação:
- mínimo de 20 avaliações válidas;
- janela móvel das últimas 100 corridas;
- score final combinado com taxa de aceitação;
- score final combinado com taxa de cancelamento;
- score final combinado com pontualidade de recolha;
- score final combinado com incidentes reportados.

Condições de recuperação para avaliação baixa:
- conclusão de formação obrigatória de qualidade e segurança;
- mínimo de 20 corridas sem incidente após bloqueio;
- média mínima de `4.2` nas últimas 30 avaliações após reativação assistida.

Brindes e incentivos para taxistas com desempenho elevado:
- bónus semanal/mensal por consistência de serviço;
- redução de comissão por escalão de qualidade;
- destaque em zonas de maior procura;
- acesso prioritário a campanhas promocionais;
- vouchers de combustível, manutenção e dados móveis;
- selo de confiança e suporte prioritário.

Brindes e incentivos para clientes:
- cupões de desconto por frequência de utilização;
- cashback em campanhas de referência;
- benefícios sazonais (prioridade em janelas de elevada procura, quando aplicável).

## 7. Endpoints Disponíveis

Autenticação:
- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`
- `POST /api/auth/social`

Utilizador:
- `GET /api/users/me`
- `PATCH /api/users/me`

Taxista:
- `GET /api/drivers/me/profile`
- `PATCH /api/drivers/me/profile`
- `PATCH /api/drivers/me/status`

Localização:
- `PUT /api/location/me`
- `GET /api/location/me`
- `GET /api/location/drivers/nearby`

Corrida:
- `POST /api/rides/request`
- `PATCH /api/rides/:rideId/respond`
- `PATCH /api/rides/:rideId/cancel`
- `PATCH /api/rides/:rideId/start`
- `PATCH /api/rides/:rideId/complete`
- `GET /api/rides/me`

Subscrição:
- `POST /api/subscriptions/me/payment`
- `GET /api/subscriptions/me/current`
- `GET /api/subscriptions/me/history`
- `GET /api/subscriptions/agent/pending` (header `x-agent-key`)
- `PATCH /api/subscriptions/agent/:subscriptionId/validate` (header `x-agent-key`)

Avaliação:
- `POST /api/ratings/driver`
- `GET /api/ratings/me/given`
- `GET /api/ratings/drivers/:driverId/summary`

Realtime:
- namespace: `WS /realtime`
- eventos servidor: `auth:error`, `map:snapshot`, `driver:status`, `driver:location`, `ride:updated`
- eventos cliente: `map:subscribe`, `map:unsubscribe`

## 8. Modelo de Dados Atual

Tabelas principais em PostgreSQL:
- `users`
- `driver_profiles`
- `user_social_identities`
- `driver_subscriptions`
- `rides`
- `driver_ratings`

Dados temporais e geoespaciais em Redis:
- OTP por telefone (`transporter:auth:otp:*`);
- localização por utilizador e índice geo (`transporter:location:*`, `transporter:location:geo`);
- presença online de taxistas.

## 9. Execução e Ambiente

### 9.1 Backend

1. Entrar em `backend`.
2. Copiar `.env.example` para `.env`.
3. Ajustar variáveis de ambiente.
4. `npm install`.
5. `npm run typecheck`.
6. `npm run build`.
7. `npm run start:dev`.

### 9.2 Mobile

1. Entrar em `mobile`.
2. `flutter pub get`.
3. `flutter analyze`.
4. `flutter test`.
5. `flutter run`.

### 9.3 Docker local

`docker-compose.yml` sobe:
- PostgreSQL (`5433:5432`);
- Redis (`6379:6379`).

Atenção:
- `backend/.env.example` usa `5432` por defeito em `DATABASE_URL`;
- com Docker local desta stack, usar `5433`.

## 10. Fragilidades e Desafios com Soluções

### 10.1 Rede instável e sincronização irregular

Fragilidade:
- perda de eventos e atraso na atualização de estado quando o dispositivo troca entre foreground/background.

Soluções recomendadas:
- confirmar receção de eventos críticos via ACK;
- persistir fila local de comandos essenciais;
- tornar operações idempotentes por chave de correlação.

### 10.2 Fraude de localização

Fragilidade:
- spoofing de GPS pode manipular matching e faturação.

Soluções recomendadas:
- validação de velocidade/aceleração e trajetória plausível;
- deteção de saltos geográficos impossíveis;
- sinalização de risco para revisão manual.

### 10.3 Escalabilidade em Tempo Real

Fragilidade:
- aumento de conexões pode sobrecarregar gateway único.

Soluções recomendadas:
- escalar horizontalmente WebSocket;
- usar Redis Pub/Sub para difusão entre instâncias;
- segmentar por região/bairro para reduzir fan-out.

### 10.4 Pagamentos e validação manual

Fragilidade:
- atraso operacional e risco humano no processo de aprovação.

Soluções recomendadas:
- webhooks e reconciliação automática;
- estados transacionais claros;
- trilha de auditoria completa por pagamento.

### 10.5 Segurança de autenticação e API

Fragilidade:
- configurações de desenvolvimento podem vazar para produção (`OTP_DEV_MODE`, CORS aberto).

Soluções recomendadas:
- perfis de ambiente obrigatórios (dev/stage/prod);
- política de CORS por lista de origens;
- rotação de segredos com validade curta;
- rate limit por IP e por conta.

### 10.6 Qualidade e regressão

Fragilidade:
- cobertura de testes ainda baixa no backend e superficial no mobile.

Soluções recomendadas:
- suite unitária para regras de negócio;
- integração para repositórios/serviços;
- E2E para fluxos críticos: auth, matching, corrida, subscrição e avaliação;
- pipeline CI obrigando checks antes de merge.

### 10.7 Viés de reputação e manipulação de avaliações

Fragilidade:
- políticas de reputação podem gerar injustiça se houver poucas avaliações ou abuso de feedback.

Soluções recomendadas:
- só aplicar penalização forte após amostra mínima de avaliações;
- ponderar recência e volume de corridas para evitar efeito de casos isolados;
- detetar padrões anómalos (avaliações em massa, fraude coordenada);
- criar canal de contestação e revisão manual para taxistas.

## 11. O Que Deve Ser Incluído na Próxima Fase

Itens de produto:
- notificações push para novos pedidos e alterações de estado;
- ETA mais preciso com motor de rotas e trânsito;
- área de suporte e incidente para cliente e taxista;
- painel operacional para validação e monitorização;
- programa de reputação com incentivos e recuperação de qualidade.

Itens técnicos:
- migrações versionadas de base de dados;
- padrão de logs estruturados com correlação por request;
- métricas de negócio e SLI/SLO (tempo de atribuição, taxa de rejeição, cancelamentos);
- estratégia de cache e retenção de dados.

Itens de segurança e conformidade:
- criptografia de dados sensíveis em repouso;
- política de retenção e anonimização de dados;
- auditoria de acesso administrativo;
- verificação reforçada de identidade do taxista.

## 12. Melhorias Estruturais no Código Atual

Backend:
- separar bootstrap de schema para migrações dedicadas;
- adicionar script `test` e suites automatizadas;
- modularizar regras longas em `subscriptions` e `rides`.

Mobile:
- dividir `ride_page.dart` e `main.dart` em componentes menores;
- introduzir estado previsivel por feature (controller/store);
- aumentar cobertura de testes widget/integration.

Repositório:
- adicionar `.github/workflows` com build/test/analyze;
- padronizar formatação e convenções de commit.

## 13. Roadmap Recomendado

Curto prazo (1-2 sprints):
- CI + testes mínimos;
- correções de ambiente e segurança;
- push notifications básicas.

Médio prazo (3-5 sprints):
- reconciliação automática de pagamentos;
- observabilidade ponta a ponta;
- melhoria de UX em corridas e tratamento de falhas.

Longo prazo:
- multi-cidade com particionamento logico;
- analytics operacional e previsão de demanda;
- abertura de APIs para parceiros.

## 14. Conclusão

O projeto já possui uma base funcional concreta e alinhada ao MVP real de mobilidade.

Para ganhar robustez de produção, a prioridade deve ser:
- testes automatizados e CI;
- segurança por ambiente;
- observabilidade;
- automação de operações críticas (pagamento, reconciliação e suporte).

## 15. Contrato de API Detalhado

### 15.1 Convenções

- prefixo global: `/api`;
- autenticação padrão: `Authorization: Bearer <token>`;
- content type: `application/json`;
- datas em `ISO-8601`;
- erros no formato padrão do NestJS.

Formato de erro esperado:

```json
{
  "statusCode": 403,
  "message": "Only drivers can access this endpoint.",
  "error": "Forbidden"
}
```

Códigos de estado mais usados:
- `200`: leitura/atualização com sucesso;
- `201`: criação em rotas `POST`;
- `400`: validação de payload ou regra de negócio;
- `401`: token inválido/ausente ou chave de agente inválida;
- `403`: role sem permissão;
- `404`: recurso inexistente;
- `429`: limite de OTP atingido.

### 15.2 Exemplos de payload (rotas críticas)

`POST /api/auth/request-otp`

```json
{
  "phone": "+258841234567"
}
```

Resposta:

```json
{
  "requestId": "uuid",
  "expiresAt": "2026-04-27T09:00:00.000Z",
  "devCode": "123456"
}
```

`POST /api/auth/verify-otp`

```json
{
  "phone": "+258841234567",
  "code": "123456",
  "role": "driver",
  "fullName": "Nome Exemplo",
  "documentId": "BI12345",
  "documentExpiry": "2028-12-31",
  "neighborhood": "Magoanine",
  "operatingRegion": "Maputo"
}
```

Resposta:

```json
{
  "accessToken": "jwt",
  "tokenType": "Bearer",
  "user": {
    "id": "uuid",
    "fullName": "Nome Exemplo",
    "phone": "+258841234567",
    "role": "driver",
    "createdAt": "2026-04-27T08:00:00.000Z"
  }
}
```

`PUT /api/location/me`

```json
{
  "lat": -25.9653,
  "lng": 32.5892
}
```

`POST /api/rides/request`

```json
{
  "pickup": { "lat": -25.9653, "lng": 32.5892 },
  "dropoff": { "lat": -25.9500, "lng": 32.6000 }
}
```

`PATCH /api/rides/:rideId/respond`

```json
{
  "action": "accept"
}
```

`POST /api/subscriptions/me/payment`

```json
{
  "plan": "monthly",
  "paymentMethod": "mpesa",
  "paymentReference": "MP-12345",
  "paymentNotes": "pagamento efetuado"
}
```

`PATCH /api/subscriptions/agent/:subscriptionId/validate`

Headers:
- `x-agent-key: <AGENT_VALIDATION_KEY>`

Body:

```json
{
  "action": "approve",
  "agentName": "Operador A",
  "notes": "confirmado no extrato"
}
```

`POST /api/ratings/driver`

```json
{
  "rideId": "uuid",
  "stars": 5,
  "comment": "viagem segura"
}
```

### 15.3 Contrato de Eventos em Tempo Real

Namespace:
- `/realtime`

Eventos cliente -> servidor:
- `map:subscribe` com `{ lat, lng, radiusKm }`
- `map:unsubscribe`

Eventos servidor -> cliente:
- `auth:error`
- `map:snapshot`
- `driver:status`
- `driver:location`
- `ride:updated`

## 16. Matriz de Ambientes e Configurações

### 16.1 Estado atual

- existe `backend/.env.example` com contrato mínimo;
- `PORT` é opcional, default `3000`;
- `docker-compose.yml` usa PostgreSQL em `5433`;
- `.env.example` aponta para `5432` e precisa ajuste local.

### 16.2 Matriz recomendada

| Variável | Dev | Staging | Prod |
|---|---|---|---|
| `PORT` | `3000` | `3000` | `3000` |
| `JWT_SECRET` | local forte | secret manager | secret manager |
| `JWT_EXPIRES_IN` | `7d` | `12h` | `15m` a `1h` |
| `OTP_DEV_MODE` | `true` | `false` | `false` |
| `OTP_TTL_SECONDS` | `300` | `300` | `180` a `300` |
| `OTP_REQUEST_COOLDOWN_SECONDS` | `30` | `30` | `45` a `60` |
| `OTP_REQUEST_WINDOW_SECONDS` | `300` | `300` | `600` |
| `OTP_MAX_REQUESTS_PER_WINDOW` | `5` | `5` | `3` a `5` |
| `AGENT_VALIDATION_KEY` | local | valor dedicado | valor dedicado + rotação |
| `DATABASE_URL` | local | staging | prod |
| `REDIS_URL` | local | staging | prod |
| `LOCATION_TTL_SECONDS` | `1800` | `900` a `1800` | `300` a `900` |

Regra operacional:
- nunca commitar `.env` real;
- segredos apenas em cofre do ambiente;
- manter checklist de variáveis por ambiente antes do deploy.

## 17. Runbook de Deploy e Rollback

### 17.1 Deploy (backend + mobile)

1. Validar branch candidata:
- backend: `npm run typecheck && npm run build`
- mobile: `flutter analyze && flutter test`

2. Preparar ambiente alvo:
- aplicar variáveis;
- validar conectividade com PostgreSQL e Redis.

3. Publicar backend.
4. Executar smoke tests:
- `POST /api/auth/request-otp`
- `GET /api/location/drivers/nearby`
- handshake em `WS /realtime`

5. Publicar mobile apontando para API do ambiente.
6. Monitorar logs e erros por 30 minutos.

### 17.2 Rollback

1. Reverter para tag estável anterior.
2. Restaurar variáveis anteriores, se necessário.
3. Reexecutar smoke tests.
4. Registrar incidente com:
- causa raiz;
- impacto;
- tempo de deteção e resolução;
- ações preventivas.

## 18. Estratégia de Dados

### 18.1 Migrações

Estado atual:
- schema é criado por bootstrap no `DatabaseService`.

Evolução indispensável:
- adotar migrações versionadas (up/down);
- bloquear alterações de schema fora de migração;
- versionar seed básica por ambiente.

### 18.2 Backup e restore

PostgreSQL:
- backup diário completo;
- backup incremental conforme capacidade do provedor;
- restore testado em staging com periodicidade definida.

Redis:
- por ser estado operacional rápido, tratar como reconstituível;
- manter snapshot/RDB se passar a armazenar dados críticos além de cache/estado efémero.

### 18.3 Retenção e ciclo de vida

Política recomendada:
- localização: TTL curto (`LOCATION_TTL_SECONDS`);
- OTP: expiração obrigatória curta;
- corridas/avaliações/subscricoes: retenção de médio/longo prazo para auditoria;
- anonimização de dados pessoais após prazo legal.

## 19. Segurança e Privacidade

### 19.1 Threat model mínimo

Ameaças principais:
- fraude de localização;
- abuso de OTP;
- token JWT comprometido;
- uso indevido de endpoints de agente;
- exposição de dados pessoais.

### 19.2 Controles técnicos

já aplicados:
- guard global de autenticação;
- validação de DTOs com `class-validator`;
- limite de emissão de OTP por janela/cooldown;
- controlo de chave de agente (`x-agent-key`).

A implementar:
- CORS com allowlist por ambiente;
- rate limit por IP e por utilizador;
- rotação de segredos e expiração curta de token;
- deteção de trajetórias improváveis (anti-spoofing).

### 19.3 Privacidade e conformidade

Diretrizes:
- minimização de coleta de dados;
- mascaramento de dados sensíveis em logs;
- auditoria de acesso administrativo;
- política clara de retenção e eliminação.

## 20. Observabilidade e Incidentes

### 20.1 Padrão de telemetria

Logs:
- estruturados em JSON;
- `requestId`, `userId` (quando houver), `route`, `statusCode`, `latencyMs`.

Métricas essenciais:
- taxa de sucesso por endpoint;
- latência P50/P95/P99;
- taxa de erro OTP (incluindo `429`);
- tempo médio de atribuição de corrida;
- taxa de cancelamento e rejeição.

SLOs iniciais sugeridos:
- disponibilidade API: `>= 99.5%` mensal;
- P95 em rotas críticas: `< 500ms` (sem contar providers externos);
- tempo médio de matching: `< 10s` em condições normais.

### 20.2 Runbook de incidente

Sev-1:
1. identificar impacto e escopo.
2. acionar rollback se necessário.
3. estabilizar serviço.
4. comunicar estado a stakeholders.
5. abrir postmortem em até 24h.

Sev-2:
1. mitigar degradação.
2. aplicar correção sem indisponibilidade ampla.
3. registar ação corretiva e preventiva.

## 21. Qualidade Obrigatória e Pipeline CI

### 21.1 Estado atual

- backend possui `typecheck` e `build`;
- mobile possui `analyze` e `test`;
- ainda sem workflow CI versionado em `.github/workflows`.

### 21.2 Gate mínimo para merge

Obrigatório:
- backend `npm run typecheck`;
- backend `npm run build`;
- mobile `flutter analyze`;
- mobile `flutter test`;
- revisão de código aprovada.

Recomendado como próximo passo:
- testes de integração backend;
- teste E2E de fluxo crítico;
- verificação de segredo no CI;
- bloqueio de merge com pipeline vermelho.

## 22. Processo de Release e Governança

Branching:
- `main` protegida;
- desenvolvimento em `feature/*`;
- hotfix em `hotfix/*`.

Versionamento:
- SemVer (`vMAJOR.MINOR.PATCH`);
- tag obrigatória por release.

Checklist de release:
1. changelog atualizado;
2. migrações aplicadas e verificadas;
3. smoke tests em staging;
4. aprovação para produção;
5. monitorização pós-deploy.

Checklist de post-release:
1. validar métricas/slo por pelo menos 30 minutos;
2. confirmar integridade de eventos em tempo real;
3. registar lições e ajustes necessários para próxima release.



