# Transporter - Documento Tecnico Aprimorado (MVP)

## 1. Resumo do Produto

O **Transporter** conecta clientes e taxistas de motorizada com base em GPS, com foco em resposta rapida e operacao simples em cenarios de mobilidade urbana informal.

Objetivo do MVP:
- cadastrar cliente e taxista;
- autenticar por telefone (OTP);
- permitir taxista ficar online/offline;
- atualizar localizacao em tempo real;
- buscar taxistas proximos;
- solicitar corrida e fazer matching automatico por distancia.

## 2. Arquitetura Escolhida

Repositorio organizado em duas aplicacoes:

- `backend/` (NestJS + TypeScript): API principal do negocio.
- `mobile/` (Flutter): app cliente/taxista com estrutura inicial modular.

Principio adotado: **modulos pequenos e focados**, evitando arquivos grandes e acoplados.

## 3. Backend MVP (Implementado)

### 3.1 Estrutura de Modulos

`backend/src/`:
- `auth/`: OTP, validacao e emissao de JWT.
- `users/`: identidade base (cliente/taxista).
- `drivers/`: perfil operacional do taxista e status online/offline.
- `location/`: atualizacao e consulta geografica.
- `rides/`: solicitacao de corrida, atribuicao e resposta do taxista.
- `realtime/`: gateway websocket para eventos em tempo real (mapa e corridas).
- `database/`: conexao PostgreSQL e bootstrap de schema.
- `redis/`: conexao Redis para presenca online e localizacao.
- `common/`: enums, guardas, decorators e utilitarios compartilhados.

### 3.2 Fluxos de Negocio Implementados

1. **Autenticacao**
- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`
- `POST /api/auth/social` (Google/Facebook com vinculo social)

2. **Taxista**
- completar perfil (documento, validade, bairro, regiao);
- manter subscricao ativa via pagamento M-Pesa/eMola;
- alterar status online/offline;
- atualizar localizacao.

3. **Cliente**
- atualizar localizacao;
- consultar taxistas proximos;
- solicitar corrida.

4. **Matching de corrida**
- busca progressiva por raio: `2km -> 5km -> 8km -> 12km`;
- prioridade pelo taxista mais proximo;
- reatribuicao automatica se taxista rejeitar.

5. **Subscricao do taxista (implementado)**
- planos disponiveis: `mensal (30 dias)`, `trimestral (90 dias)`, `semestral (180 dias)`, `anual (365 dias)`;
- pagamento via `M-Pesa` ou `eMola`;
- cada pagamento entra em estado `pending_validation`;
- validacao manual por agentes liberada apos 30 minutos;
- aprovacao ativa a subscricao e expiracao calculada conforme o plano.

6. **Tempo real (WebSocket)**
- autenticacao JWT no handshake;
- canal de mapa com eventos de status/localizacao de taxistas online;
- canal de corrida com eventos de atualizacao para cliente e taxista envolvidos.

7. **Avaliacao de taxistas (implementado)**
- cliente avalia de `1` a `5` estrelas apos corrida concluida;
- escala de satisfacao: `1 insatisfeito`, `2 pouco satisfeito`, `3 satisfeito`, `4 muito satisfeito`, `5 super satisfeito`;
- media e distribuicao por estrelas disponiveis por taxista.

### 3.3 Endpoints MVP

- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`
- `POST /api/auth/social`
- `GET /api/users/me`
- `PATCH /api/users/me`
- `GET /api/drivers/me/profile`
- `PATCH /api/drivers/me/profile`
- `PATCH /api/drivers/me/status`
- `PUT /api/location/me`
- `GET /api/location/me`
- `GET /api/location/drivers/nearby`
- `POST /api/rides/request`
- `PATCH /api/rides/:rideId/respond`
- `PATCH /api/rides/:rideId/cancel`
- `PATCH /api/rides/:rideId/start`
- `PATCH /api/rides/:rideId/complete`
- `GET /api/rides/me`
- `POST /api/subscriptions/me/payment`
- `GET /api/subscriptions/me/current`
- `GET /api/subscriptions/me/history`
- `GET /api/subscriptions/agent/pending` (header `x-agent-key`)
- `PATCH /api/subscriptions/agent/:subscriptionId/validate` (header `x-agent-key`)
- `POST /api/ratings/driver`
- `GET /api/ratings/me/given`
- `GET /api/ratings/drivers/:driverId/summary`
- `WS /realtime`:
  - receber: `auth:error`, `map:snapshot`, `driver:status`, `driver:location`, `ride:updated`
  - enviar: `map:subscribe`, `map:unsubscribe`

## 4. Modelo de Dados (MVP)

### 4.1 User
- `id`
- `fullName`
- `phone`
- `role` (`client` | `driver`)

### 4.2 DriverProfile
- `userId`
- `documentId`
- `documentExpiry`
- `neighborhood`
- `operatingRegion`
- `status` (`online` | `offline`)

### 4.3 Location
- `userId`
- `coordinates` (`lat`, `lng`)
- `updatedAt`

### 4.4 Ride
- `id`
- `clientId`
- `driverId` (opcional)
- `pickup`
- `dropoff` (opcional)
- `status` (`searching`, `assigned`, `accepted`, `in_progress`, `cancelled`, `completed`, etc.)
- `searchRadiusKm`
- `rejectedDriverIds`

## 5. Estrutura Mobile (Implementada)

`mobile/lib/`:
- `core/`: tema e cores.
- `features/auth/presentation/`: tela de login OTP.
- `features/map/presentation/`: tela de taxistas proximos.
- `features/ride/presentation/`: inicio do fluxo de corrida.
- `models/`: modelos de dominio (`Driver`, `Ride`, `GeoPoint`).
- `services/`: cliente HTTP, autenticacao OTP, localizacao e websocket realtime.

## 6. Regras Tecnicas e de Manutencao

- Cada modulo possui responsabilidade unica.
- Regras de validacao separadas em servicos dedicados.
- Logica de matching separada da logica de persistencia de corrida.
- Sem arquivos monoliticos: preferencia por submodulos menores.
- DTOs com `class-validator` para blindar entrada da API.
- Repositorios de `users`, `drivers` e `rides` persistem em PostgreSQL.
- Presenca online de taxistas e localizacao em tempo real persistidas em Redis.
- Busca de taxistas proximos otimizada com indice geoespacial Redis (`GEOSEARCH`).

## 7. Seguranca MVP

Ja aplicado:
- JWT para rotas autenticadas;
- guard global com suporte a rotas publicas;
- OTP com expiração e limite de tentativas;
- rate limit de OTP por telefone (cooldown entre requisicoes e limite por janela).
- chave de agente (`AGENT_VALIDATION_KEY`) para validar subscricoes manualmente.

Para proxima iteracao:
- integracao real com provedor SMS;
- rate limiting por IP;
- persistencia de sessoes em Redis;
- verificacao criptografica de pagamentos M-Pesa/eMola com reconciliacao automatica;
- auditoria e rastreio anti-fraude de localizacao.

## 8. Como Executar

### Backend

1. `cd backend`
2. copiar `.env.example` para `.env`
3. garantir PostgreSQL ativo e acessivel pelas variaveis do `.env`
4. garantir Redis ativo e acessivel pelas variaveis do `.env`
5. `npm install`
6. `npm run start:dev`

API disponivel em: `http://localhost:3000/api`

### Mobile

1. `cd mobile`
2. `flutter pub get`
3. `flutter run`

## 9. Proximos Passos Recomendados

1. Implementar notificacoes push para novos pedidos de corrida.
2. Criar testes E2E (auth, online/offline, ride matching, reatribuicao, subscricao e avaliacao).
3. Integrar reconciliacao automatica dos pagamentos M-Pesa/eMola.
4. Persistir historico analitico de busca/matching para observabilidade operacional.

## 10. Status Atual

O projeto ja possui uma base funcional para evolucao do MVP, com foco em simplicidade, clareza arquitetural e manutencao facilitada.
