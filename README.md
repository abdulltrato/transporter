# transporter
Aplicação mobile para conectar taxistas de motorizada e clientes em tempo real, com base em localização (GPS).

# 🚀 Transporter — Documento de Desenvolvimento (MVP)

Aplicação mobile para conectar **taxistas de motorizada** e **clientes** em tempo real, com base em localização (GPS).

---

# 📌 1. Visão Geral

O **Transporter** é um aplicativo que permite:

* Cadastro de taxistas e clientes
* Localização automática via GPS
* Busca de taxistas mais próximos
* Solicitação de corridas

📍 Ideal para uso em bairros e cidades com transporte informal.

---

# 🎯 2. Objetivo do MVP

Criar uma versão inicial simples com:

✔ Cadastro de usuários
✔ Login com telefone
✔ Localização em tempo real
✔ Visualização de taxistas próximos
✔ Solicitação de corrida

---

# 👥 3. Tipos de Usuários

## 🏍️ Taxista

Informações obrigatórias:

* Nome completo
* Documento de identificação válido
* Data de validade do documento
* Bairro / residência
* Região de atuação

Funcionalidades:

* Ficar Online / Offline
* Atualizar localização
* Receber pedidos de corrida

---

## 🙋 Cliente

Informações:

* Nome completo
* Número de telefone

Funcionalidades:

* Ver taxistas no mapa
* Solicitar corrida
* Ver tempo estimado

---

# 🧱 4. Tecnologias Recomendadas

## 📱 Mobile (Frontend)

**Flutter (RECOMENDADO)**

* Um único código para Android e iOS
* Alta performance
* Fácil para iniciantes

Alternativa:

* React Native

---

## 🧠 Backend

* Node.js + TypeScript
* Framework: NestJS

✔ Seguro
✔ Organizado
✔ Escalável

---

## 🗄️ Banco de Dados

* PostgreSQL → dados principais
* Redis → localização em tempo real

---

## 📍 Geolocalização

* GPS do dispositivo
* Google Maps API

---

## 🔐 Autenticação

* Login com número de telefone (OTP)
* JWT (tokens de sessão)

---

# ⚙️ 5. Funcionalidades do Sistema

## 🔐 Autenticação

* Registro (taxista ou cliente)
* Login com código SMS

---

## 🏍️ Taxista

* Definir status (Online/Offline)
* Enviar localização continuamente
* Receber pedidos

---

## 🙋 Cliente

* Ver mapa com taxistas
* Solicitar corrida
* Buscar automaticamente o mais próximo

---

# 🔎 6. Lógica de Busca (Importante)

Quando cliente pede corrida:

1. Procurar taxistas num raio de 2 km
2. Se não encontrar:
   → aumentar para 5 km
3. Continuar até encontrar disponível

✔ Sempre priorizar os mais próximos

---

# 🗂️ 7. Estrutura do Projeto

## 📱 Flutter

```
lib/
 ├── core/            # Configurações gerais
 ├── features/        # Funcionalidades
 │    ├── auth/
 │    ├── map/
 │    ├── ride/
 │
 ├── models/          # Modelos de dados
 ├── services/        # Comunicação com API
 └── main.dart
```

---

## 🧠 Backend (NestJS)

```
src/
 ├── auth/
 ├── users/
 ├── drivers/
 ├── rides/
 ├── location/
 ├── common/
 └── main.ts
```

---

# 🧾 8. Modelo de Dados

## 🏍️ Taxista

```json
{
  "id": "uuid",
  "nome": "string",
  "documento": "string",
  "validadeDocumento": "date",
  "bairro": "string",
  "regiao": "string",
  "localizacao": {
    "lat": "number",
    "lng": "number"
  },
  "status": "online | offline"
}
```

---

## 🙋 Cliente

```json
{
  "id": "uuid",
  "nome": "string",
  "telefone": "string",
  "localizacao": {
    "lat": "number",
    "lng": "number"
  }
}
```

---

# 🔐 9. Segurança (Muito Importante)

* Usar HTTPS
* Criptografar senhas (bcrypt)
* Validar documentos
* Proteção contra localização falsa
* Limitar requisições (rate limit)

---

# ☁️ 10. Deploy

* Backend: Render / Railway / AWS
* Banco de dados: PostgreSQL (Supabase recomendado)
* Armazenamento: Firebase Storage

---

# 📈 11. Evoluções Futuras

Depois do MVP:

* 💰 Pagamentos (M-Pesa, etc.)
* ⭐ Avaliação de taxistas
* 📜 Histórico de corridas
* 💬 Chat cliente ↔ taxista
* 🔔 Notificações push

---

# 🚧 12. Desafios Reais

* Internet instável
* Precisão do GPS
* Segurança dos usuários
* Escalabilidade do sistema

---

# 💡 13. Estratégia de Desenvolvimento

⚠️ Não comece grande demais.

Comece assim:

1. Uma cidade ou bairro
2. Poucos taxistas reais
3. Testes práticos

Depois evolua.

---

# ✅ 14. Plano de Desenvolvimento

### Fase 1

* Cadastro
* Login
* Banco de dados

### Fase 2

* GPS
* Mapa
* Localização em tempo real

### Fase 3

* Solicitação de corrida
* Matching cliente ↔ taxista

---

# 🎯 Conclusão

O Transporter deve começar simples, funcional e confiável.

👉 Primeiro faça funcionar
👉 Depois faça bonito
👉 Depois escale

🚀
