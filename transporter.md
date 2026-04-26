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
- `common/`: enums, guardas, decorators e utilitarios compartilhados.

### 3.2 Fluxos de Negocio Implementados

1. **Autenticacao**
- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`

2. **Taxista**
- completar perfil (documento, validade, bairro, regiao);
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

### 3.3 Endpoints MVP

- `POST /api/auth/request-otp`
- `POST /api/auth/verify-otp`
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
- `GET /api/rides/me`

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
- `status` (`searching`, `assigned`, `accepted`, `cancelled`, etc.)
- `searchRadiusKm`
- `rejectedDriverIds`

## 5. Estrutura Mobile (Implementada)

`mobile/lib/`:
- `core/`: tema e cores.
- `features/auth/presentation/`: tela de login OTP.
- `features/map/presentation/`: tela de taxistas proximos.
- `features/ride/presentation/`: inicio do fluxo de corrida.
- `models/`: modelos de dominio (`Driver`, `Ride`, `GeoPoint`).
- `services/`: cliente HTTP e servicos de integracao.

## 6. Regras Tecnicas e de Manutencao

- Cada modulo possui responsabilidade unica.
- Regras de validacao separadas em servicos dedicados.
- Logica de matching separada da logica de persistencia de corrida.
- Sem arquivos monoliticos: preferencia por submodulos menores.
- DTOs com `class-validator` para blindar entrada da API.

## 7. Seguranca MVP

Ja aplicado:
- JWT para rotas autenticadas;
- guard global com suporte a rotas publicas;
- OTP com expiração e limite de tentativas.

Para proxima iteracao:
- integracao real com provedor SMS;
- rate limiting por IP/telefone;
- persistencia de OTP e sessoes em Redis;
- auditoria e rastreio anti-fraude de localizacao.

## 8. Como Executar

### Backend

1. `cd backend`
2. copiar `.env.example` para `.env`
3. `npm install`
4. `npm run start:dev`

API disponivel em: `http://localhost:3000/api`

### Mobile

1. `cd mobile`
2. `flutter pub get`
3. `flutter run`

## 9. Proximos Passos Recomendados

1. Substituir repositorios em memoria por PostgreSQL (users, drivers, rides).
2. Mover localizacao e presenca online para Redis (baixa latencia).
3. Adicionar websocket para atualizacao de mapa em tempo real.
4. Implementar notificacoes push para novos pedidos de corrida.
5. Criar testes E2E (auth, online/offline, ride matching, reatribuicao).

## 10. Status Atual

O projeto ja possui uma base funcional para evolucao do MVP, com foco em simplicidade, clareza arquitetural e manutencao facilitada.
