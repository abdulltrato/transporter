# Transporter - Documento Tecnico Consolidado

## 1. Visao Geral

O Transporter e uma plataforma de mobilidade para ligar clientes e taxistas de motorizada com base em geolocalizacao e operacao em tempo real.

Contexto do produto:
- foco em cenarios de transporte urbano informal;
- necessidade de resposta rapida com internet instavel;
- importancia de confiabilidade operacional e seguranca basica desde o MVP.

Estado atual:
- backend funcional em NestJS com API e WebSocket;
- app Flutter funcional com tres areas principais: acesso, mapa e corrida;
- suporte a subscricao do taxista e avaliacao de servico.

## 2. Propositos de Uma App Como Esta

Uma app deste tipo deve ir alem de "pedir motorizada":
- reduzir tempo de espera e incerteza do cliente;
- organizar oferta de taxistas por proximidade e disponibilidade real;
- melhorar renda do taxista por distribuicao mais justa de corridas;
- registrar historico de operacao para auditoria e melhoria continua;
- habilitar camada financeira (subscricao, pagamentos, eventualmente repasses);
- criar base para servicos derivados: entregas, corridas programadas, clientes corporativos.

## 3. Arquitetura Atual do Repositorio

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

## 4. Backend - Modulos e Responsabilidades

Modulos atuais em `backend/src`:
- `auth`: OTP, token JWT, login social e controle de identidade.
- `users`: perfil base do utilizador.
- `drivers`: perfil operacional do taxista e estado online/offline.
- `location`: escrita e consulta de localizacao.
- `rides`: ciclo de vida de corrida e reatribuicao.
- `subscriptions`: planos, pagamento e validacao por agente.
- `ratings`: avaliacao de taxista e resumo por estrelas.
- `realtime`: gateway WebSocket e emissao de eventos.
- `database`: conexao PostgreSQL e bootstrap de schema.
- `redis`: conexao Redis.
- `common`: enums, decorators, guardas, interfaces e utilitarios.

Pontos tecnicos ja aplicados:
- validacao global com `ValidationPipe` (`whitelist`, `forbidNonWhitelisted`, `transform`);
- prefixo global `/api`;
- guard global de autenticacao com excecao de rotas publicas;
- matching por distancia com raio progressivo;
- indice geoespacial Redis com `GEOSEARCH`.

## 5. Mobile - Estrutura e Comportamento Atual

Estrutura atual em `mobile/lib`:
- `core/`: tema e identidade visual.
- `features/auth/presentation`: login OTP/social, role e comandos de sessao.
- `features/map/presentation`: estado realtime e lista de taxistas proximos.
- `features/ride/presentation`: orquestracao da corrida (solicitar, responder, iniciar, concluir, cancelar), subscricao e avaliacao.
- `models/`: tipos de dominio.
- `services/`: cliente HTTP, sessao, localizacao, realtime, subscricao e avaliacao.

### Modo Nativo Robusto (ja integrado)

Objetivo:
- reduzir perda de sincronizacao em rede instavel e durante transicoes de lifecycle.

Implementacao atual:
- `NativeRuntimeService` com fila coalescida de localizacao;
- retentativas com backoff exponencial;
- pausa em background e retoma em foreground;
- snapshot de estado exposto para UI;
- `RealtimeMapService` com reconexao progressiva e tratamento de `auth:error`.

## 6. Fluxos Funcionais Implementados

1. Onboarding e autenticacao.
- OTP por telefone (`request-otp`, `verify-otp`).
- login social (`social`) com vinculacao de identidade.

2. Operacao do taxista.
- completar perfil.
- manter estado online/offline.
- atualizar localizacao.
- manter subscricao ativa.

3. Operacao do cliente.
- atualizar localizacao.
- ver taxistas proximos.
- solicitar corrida.

4. Ciclo de corrida.
- criacao de pedido.
- atribuicao inicial por proximidade.
- aceite/rejeicao do taxista.
- reatribuicao automatica apos rejeicao.
- inicio, conclusao e cancelamento.

5. Qualidade do servico.
- avaliacao 1..5 apos corrida concluida.
- consulta de resumo por taxista.

## 7. Endpoints Disponiveis

Autenticacao:
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

Localizacao:
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

Subscricao:
- `POST /api/subscriptions/me/payment`
- `GET /api/subscriptions/me/current`
- `GET /api/subscriptions/me/history`
- `GET /api/subscriptions/agent/pending` (header `x-agent-key`)
- `PATCH /api/subscriptions/agent/:subscriptionId/validate` (header `x-agent-key`)

Avaliacao:
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
- localizacao por utilizador e indice geo (`transporter:location:*`, `transporter:location:geo`);
- presenca online de taxistas.

## 9. Execucao e Ambiente

### 9.1 Backend

1. Entrar em `backend`.
2. Copiar `.env.example` para `.env`.
3. Ajustar variaveis de ambiente.
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

Atencao:
- `backend/.env.example` usa `5432` por defeito em `DATABASE_URL`;
- com Docker local desta stack, usar `5433`.

## 10. Fragilidades e Desafios com Solucoes

### 10.1 Rede instavel e sincronizacao irregular

Fragilidade:
- perda de eventos e atraso na atualizacao de estado quando o dispositivo troca entre foreground/background.

Solucoes recomendadas:
- confirmar rececao de eventos criticos via ACK;
- persistir fila local de comandos essenciais;
- tornar operacoes idempotentes por chave de correlacao.

### 10.2 Fraude de localizacao

Fragilidade:
- spoofing de GPS pode manipular matching e faturacao.

Solucoes recomendadas:
- validacao de velocidade/aceleracao e trajetoria plausivel;
- deteccao de saltos geograficos impossiveis;
- sinalizacao de risco para revisao manual.

### 10.3 Escalabilidade realtime

Fragilidade:
- aumento de conexoes pode sobrecarregar gateway unico.

Solucoes recomendadas:
- escalar horizontalmente WebSocket;
- usar Redis Pub/Sub para difusao entre instancias;
- segmentar por regiao/bairro para reduzir fan-out.

### 10.4 Pagamentos e validacao manual

Fragilidade:
- atraso operacional e risco humano no processo de aprovacao.

Solucoes recomendadas:
- webhooks e reconciliacao automatica;
- estados transacionais claros;
- trilha de auditoria completa por pagamento.

### 10.5 Seguranca de autenticacao e API

Fragilidade:
- configuracoes de desenvolvimento podem vazar para producao (`OTP_DEV_MODE`, CORS aberto).

Solucoes recomendadas:
- perfis de ambiente obrigatorios (dev/stage/prod);
- politica de CORS por lista de origens;
- rotacao de segredos com validade curta;
- rate limit por IP e por conta.

### 10.6 Qualidade e regressao

Fragilidade:
- cobertura de testes ainda baixa no backend e superficial no mobile.

Solucoes recomendadas:
- suite unit para regras de negocio;
- integracao para repositorios/servicos;
- E2E para fluxos criticos: auth, matching, corrida, subscricao e avaliacao;
- pipeline CI obrigando checks antes de merge.

## 11. O Que Deve Ser Incluido na Proxima Fase

Itens de produto:
- notificacoes push para novos pedidos e alteracoes de estado;
- ETA mais preciso com motor de rotas e transito;
- area de suporte e incidente para cliente e taxista;
- painel operacional para validacao e monitorizacao.

Itens tecnicos:
- migracoes versionadas de base de dados;
- padrao de logs estruturados com correlacao por request;
- metricas de negocio e SLI/SLO (tempo de atribuicao, taxa de rejeicao, cancelamentos);
- estrategia de cache e retencao de dados.

Itens de seguranca e conformidade:
- criptografia de dados sensiveis em repouso;
- politica de retencao e anonimacao de dados;
- auditoria de acesso administrativo;
- verificacao reforcada de identidade do taxista.

## 12. Melhorias Estruturais no Codigo Atual

Backend:
- separar bootstrap de schema para migracoes dedicadas;
- adicionar script `test` e suites automatizadas;
- modularizar regras longas em `subscriptions` e `rides`.

Mobile:
- dividir `ride_page.dart` e `main.dart` em componentes menores;
- introduzir estado previsivel por feature (controller/store);
- aumentar cobertura de testes widget/integration.

Repositorio:
- adicionar `.github/workflows` com build/test/analyze;
- padronizar formatacao e convencoes de commit.

## 13. Roadmap Recomendado

Curto prazo (1-2 sprints):
- CI + testes minimos;
- correcoes de ambiente e seguranca;
- push notifications basicas.

Medio prazo (3-5 sprints):
- reconciliacao automatica de pagamentos;
- observabilidade ponta a ponta;
- melhoria de UX em corridas e tratamento de falhas.

Longo prazo:
- multi-cidade com particionamento logico;
- analytics operacional e previsao de demanda;
- abertura de APIs para parceiros.

## 14. Conclusao

O projeto ja possui uma base funcional concreta e alinhada ao MVP real de mobilidade.

Para ganhar robustez de producao, a prioridade deve ser:
- testes automatizados e CI;
- seguranca por ambiente;
- observabilidade;
- automacao de operacoes criticas (pagamento, reconciliacao e suporte).
