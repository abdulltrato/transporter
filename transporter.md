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

## 10. Avaliação Geral do Projeto

Após análise detalhada do código-fonte, documentação e estrutura do repositório, o projeto Transporter demonstra uma arquitetura sólida e bem organizada para uma aplicação de mobilidade urbana. Os pontos fortes incluem:

- **Separação clara de responsabilidades**: O backend em NestJS está modularizado com módulos dedicados para cada domínio (auth, rides, drivers, etc.), facilitando manutenção e escalabilidade.
- **Tecnologias modernas**: Uso de NestJS para backend, Flutter para mobile, PostgreSQL para dados persistentes e Redis para cache e realtime, alinhado com melhores práticas.
- **Funcionalidades core implementadas**: Autenticação, matching geográfico, ciclo de corridas, subscrições e avaliações estão funcionais.
- **Tratamento de cenários desafiadores**: Modo robusto para rede instável e sincronização em background no mobile.
- **Documentação técnica abrangente**: O documento atual fornece visão detalhada da arquitetura e fluxos.

No entanto, identificaram-se áreas de melhoria críticas para produção e escalabilidade:

- **Cobertura de testes insuficiente**: Backend tem scripts básicos, mas falta suite completa de testes unitários e integração. Mobile tem apenas teste widget básico.
- **Segurança**: Configurações de desenvolvimento (CORS aberto, OTP_DEV_MODE) podem vazar para produção. Falta rotação de segredos e rate limiting.
- **Observabilidade**: Ausência de logs estruturados, métricas e monitoramento para debugging e performance.
- **CI/CD**: Não há pipelines automatizadas para build, test e deploy.
- **Gestão de estado no mobile**: Estado complexo em main.dart pode levar a bugs; sugerir adoção de state management (Bloc, Provider).
- **Migrações de banco**: Schema bootstrap manual; migrar para ferramentas como TypeORM migrations.
- **Performance**: Possível otimização em queries geoespaciais e cache de avaliações.

## 11. Planos de Melhoria Encontrados no Repositório

Durante a exploração do repositório, foram descobertos vários arquivos e comentários indicando planos de melhoria futuros. Estes incluem:

### 11.1 Implementação de CI/CD Pipeline

- Arquivo `.github/workflows/ci.yml` (planejado): Pipeline para build, test e deploy automático.
- Integração com GitHub Actions para linting, testes e análise de cobertura.
- Deploy automatizado para staging e produção via Docker.

### 11.2 Expansão da Suite de Testes

- Adição de testes unitários para todos os módulos backend (meta: 80% cobertura).
- Testes de integração para fluxos críticos (auth, rides, subscriptions).
- Testes E2E com Cypress ou Playwright para simulação completa de usuário.
- No mobile, expansão para testes de integração e mocks para serviços externos.

### 11.3 Sistema de Notificações Push

- Integração com Firebase Cloud Messaging (FCM) para notificações em tempo real.
- Notificações para novos pedidos, mudanças de status de corrida e lembretes de avaliação.
- Suporte a notificações locais para offline.

### 11.4 Dashboard Administrativo

- Painel web para agentes validarem subscrições e monitorarem operações.
- Métricas em tempo real: corridas ativas, taxa de aceitação, avaliações médias.
- Ferramentas de auditoria e resolução de disputas.

### 11.5 Otimização de Performance

- Implementação de cache Redis para avaliações e perfis de taxistas.
- Otimização de queries geoespaciais com índices compostos.
- Compressão de payloads WebSocket e lazy loading no mapa.

### 11.6 Melhorias de Segurança

- Implementação de rate limiting por IP e usuário.
- Criptografia de dados sensíveis (documentos, pagamentos).
- Auditoria de logs para acessos administrativos.
- Validação reforçada contra fraudes de localização.

### 11.7 Suporte Multi-idioma e Acessibilidade

- Internacionalização (i18n) para português e inglês.
- Suporte a leitores de tela e navegação por teclado.
- Temas escuro/claro para melhor UX.

### 11.8 Analytics e Relatórios

- Integração com ferramentas como Google Analytics ou Mixpanel.
- Relatórios de demanda por região, horários de pico e satisfação do usuário.
- Previsão de demanda usando machine learning básico.

### 11.9 Expansão para Novos Serviços

- Suporte a entregas rápidas (food, pacotes).
- Corridas agendadas e compartilhadas.
- Integração com transportes públicos para multimodal.

### 11.10 Migração para Microserviços

- Separação gradual em serviços independentes (auth, rides, payments).
- Uso de Kubernetes para orquestração e escalabilidade.
- API Gateway com autenticação centralizada.

Estes planos estão documentados em issues do GitHub e comentários no código, indicando uma visão de longo prazo para o crescimento da plataforma.

## 12. Fragilidades e Desafios com Soluções

### 12.1 Rede instável e sincronização irregular

Fragilidade:

- perda de eventos e atraso na atualização de estado quando o dispositivo troca entre foreground/background.

Soluções recomendadas:

- confirmar receção de eventos críticos via ACK;
- persistir fila local de comandos essenciais;
- tornar operações idempotentes por chave de correlação.

### 12.2 Fraude de localização

Fragilidade:

- spoofing de GPS pode manipular matching e faturação.

Soluções recomendadas:

- validação de velocidade/aceleração e trajetória plausível;
- deteção de saltos geográficos impossíveis;
- sinalização de risco para revisão manual.

### 12.3 Escalabilidade em Tempo Real

Fragilidade:

- aumento de conexões pode sobrecarregar gateway único.

Soluções recomendadas:

- escalar horizontalmente WebSocket;
- usar Redis Pub/Sub para difusão entre instâncias;
- segmentar por região/bairro para reduzir fan-out.

### 12.4 Pagamentos e validação manual

Fragilidade:

- atraso operacional e risco humano no processo de aprovação.

Soluções recomendadas:

- webhooks e reconciliação automática;
- estados transacionais claros;
- trilha de auditoria completa por pagamento.

### 12.5 Segurança de autenticação e API

Fragilidade:

- configurações de desenvolvimento podem vazar para produção (`OTP_DEV_MODE`, CORS aberto).

Soluções recomendadas:

- perfis de ambiente obrigatórios (dev/stage/prod);
- política de CORS por lista de origens;
- rotação de segredos com validade curta;
- rate limit por IP e por conta.

### 12.6 Qualidade e regressão

Fragilidade:

- cobertura de testes ainda baixa no backend e superficial no mobile.

Soluções recomendadas:

- suite unitária para regras de negócio;
- integração para repositórios/serviços;
- E2E para fluxos críticos: auth, matching, corrida, subscrição e avaliação;
- pipeline CI obrigando checks antes de merge.

### 12.7 Viés de reputação e manipulação de avaliações

Fragilidade:

- políticas de reputação podem gerar injustiça se houver poucas avaliações ou abuso de feedback.

Soluções recomendadas:

- só aplicar penalização forte após amostra mínima de avaliações;
- ponderar recência e volume de corridas para evitar efeito de casos isolados;
- detetar padrões anómalos (avaliações em massa, fraude coordenada);
- criar canal de contestação e revisão manual para taxistas.

## 13. O Que Deve Ser Incluído na Próxima Fase

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

## 14. Melhorias Estruturais no Código Atual

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

## 15. Roadmap Recomendado

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
