# Plataforma central de gestão de custos de IA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar o novo serviço `/gestao-ia/` que recebe consumo de IA, calcula custos, aplica limites mensais e oferece administração central com Microsoft 365.

**Architecture:** Aplicação Next.js 16 independente, com módulos de domínio `.mjs` testáveis pelo `node:test`, rotas server-side e PostgreSQL/Supabase protegido por RLS. Os módulos consumidores usam uma API interna autenticada para reservar custo e liquidar eventos; o navegador usa somente APIs administrativas autenticadas.

**Tech Stack:** Node.js 20+, pnpm 9, Next.js 16, React 19, TypeScript 5.9, Supabase JS 2.76, PostgreSQL, Recharts, Lucide React, Zod, node:test e Playwright.

## Global Constraints

- Repositório: `AppelementosIA/solutiongroup-ia-gestao`.
- Serviço EasyPanel: `solutiongroup-gestao-ia`.
- URL pública: `https://ia.solutiongroup.com.br/gestao-ia/`.
- Base path obrigatório: `/gestao-ia` em páginas, assets, APIs e redirects.
- Período mensal e datas operacionais: `America/Sao_Paulo`.
- Valores de limite em BRL; custo original e tarifa preservados em USD.
- Nunca persistir prompts, respostas, documentos, tokens de acesso ou chaves.
- RLS habilitada e nenhuma leitura direta do navegador no Supabase.
- Falha da telemetria ou da central não derruba o módulo consumidor.
- Usar português natural com acentos e cedilhas em toda a interface.
- O custo exibido deve ser identificado como `Custo estimado`.

---

## File Map

- `package.json`: scripts e dependências do serviço.
- `next.config.mjs`: build standalone e base path.
- `src/shared/paths.mjs`: normalização única de caminhos.
- `src/domain/usage.mjs`: normalização e sanitização dos eventos.
- `src/domain/pricing.mjs`: tarifas, câmbio e estimativa de custo.
- `src/domain/policies.mjs`: cálculo de políticas aplicáveis e estado dos limites.
- `src/server/repository.mjs`: acesso server-side ao Supabase.
- `src/server/integration-auth.mjs`: autenticação das integrações.
- `src/server/internal-handlers.mjs`: reserva, liquidação, cancelamento, evento e heartbeat.
- `src/server/admin-handlers.mjs`: dashboard e manutenção administrativa.
- `src/server/auth/*`: sessão Microsoft e autorização por perfil.
- `app/api/internal/v1/**`: adaptadores HTTP finos para módulos.
- `app/api/admin/v1/**`: adaptadores HTTP finos para a interface.
- `app/(admin)/**`: páginas privadas.
- `components/**`: shell, filtros, indicadores, gráficos, tabelas e formulários.
- `supabase/migrations/**`: ledger, controle orçamentário e administração.
- `supabase/checks/**`: contratos SQL de segurança e funções.
- `test/**`: testes de domínio, handlers, auth e contratos de interface.
- `e2e/**`: fluxos Playwright em desktop e mobile.
- `infra/docker/Dockerfile`: imagem standalone para EasyPanel.
- `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`: publicação e rollback.

## Execution Setup

Antes da Task 1, executar:

```powershell
New-Item -ItemType Directory -Path "C:\Users\Torqu\Documents\solutiongroup-ia-gestao"
Set-Location "C:\Users\Torqu\Documents\solutiongroup-ia-gestao"
git init -b main
git commit --allow-empty -m "chore: initialize repository"
git switch -c codex/gestao-ia-platform
```

Todas as Tasks 1 a 11 são executadas nessa branch; a publicação em `main` ocorre somente após a matriz final verde.

### Task 1: Bootstrap do repositório e contrato de base path

**Files:**
- Create: `package.json`
- Create: `pnpm-workspace.yaml`
- Create: `tsconfig.json`
- Create: `next-env.d.ts`
- Create: `next.config.mjs`
- Create: `.gitignore`
- Create: `.dockerignore`
- Create: `.env.example`
- Create: `src/shared/paths.mjs`
- Create: `test/paths.test.mjs`
- Create: `app/layout.tsx`
- Create: `app/page.tsx`
- Create: `app/globals.css`

**Interfaces:**
- Produces: `normalizeBasePath(value): string` e `withBasePath(pathname, basePath): string`.
- Produces: scripts `test`, `lint`, `build`, `dev`, `start` e `test:e2e`.

- [ ] **Step 1: Escrever o teste falho do base path**

```js
import test from "node:test";
import assert from "node:assert/strict";
import { normalizeBasePath, withBasePath } from "../src/shared/paths.mjs";

test("normaliza /gestao-ia sem duplicar barras", () => {
  assert.equal(normalizeBasePath("/gestao-ia/"), "/gestao-ia");
  assert.equal(withBasePath("/api/admin/v1/dashboard", "/gestao-ia/"),
    "/gestao-ia/api/admin/v1/dashboard");
});
```

- [ ] **Step 2: Executar o teste e confirmar a falha**

Run: `node --test test/paths.test.mjs`
Expected: FAIL com `ERR_MODULE_NOT_FOUND` para `src/shared/paths.mjs`.

- [ ] **Step 3: Criar o helper e o scaffold mínimo**

```js
export function normalizeBasePath(value = "") {
  const normalized = String(value).trim().replace(/\/+$/, "");
  return normalized && normalized !== "/" ? `/${normalized.replace(/^\/+/, "")}` : "";
}

export function withBasePath(pathname, basePath = process.env.NEXT_PUBLIC_APP_BASE_PATH) {
  const base = normalizeBasePath(basePath);
  const path = `/${String(pathname || "").replace(/^\/+/, "")}`;
  return `${base}${path}`;
}
```

Configurar `next.config.mjs` com `output: "standalone"`, `typedRoutes: true` e `basePath` derivado de `APP_BASE_PATH || NEXT_PUBLIC_APP_BASE_PATH`. Configurar `package.json` com `next@^16.0.0`, `react@^19.2.0`, `react-dom@^19.2.0`, `@supabase/supabase-js@^2.76.0`, `zod`, `jose`, `cookie`, `lucide-react`, `recharts`, `nodemailer` e `ajv` e `@playwright/test` como dependências de desenvolvimento.

- [ ] **Step 4: Instalar e validar o scaffold**

Run: `pnpm install && pnpm test && pnpm lint && pnpm build`
Expected: todos os comandos terminam com código `0`; a rota `/gestao-ia/` compila.

- [ ] **Step 5: Commit**

```bash
git add package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.json next-env.d.ts next.config.mjs .gitignore .dockerignore .env.example src/shared test/paths.test.mjs app
git commit -m "chore: bootstrap central ai cost platform"
```

### Task 2: Ledger central, tabelas administrativas e RLS

**Files:**
- Create: `supabase/migrations/202608010001_central_ai_usage_ledger.sql`
- Create: `supabase/checks/central_ai_usage_contract.sql`
- Create: `scripts/validate-sql-contract.mjs`
- Modify: `package.json`

**Interfaces:**
- Produces: tabelas `ai_usage_events`, `ai_provider_prices`, `ai_exchange_rates`, `ai_integrations`, `ai_admin_users`, `ai_alerts` e `ai_audit_log`.
- Produces: unicidade `(service, source_event_id)` e acesso exclusivo de `service_role`.

- [ ] **Step 1: Escrever o validador falho do contrato SQL**

```js
import { readFile } from "node:fs/promises";

const migration = await readFile(
  new URL("../supabase/migrations/202608010001_central_ai_usage_ledger.sql", import.meta.url),
  "utf8"
);
const required = [
  "create table public.ai_usage_events",
  "unique (service, source_event_id)",
  "enable row level security",
  "revoke all on public.ai_usage_events from public, anon, authenticated",
  "grant select, insert on public.ai_usage_events to service_role"
];
for (const fragment of required) {
  if (!migration.toLowerCase().includes(fragment)) throw new Error(`Ausente: ${fragment}`);
}
```

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node scripts/validate-sql-contract.mjs`
Expected: FAIL informando que a migration não existe.

- [ ] **Step 3: Criar a migration completa**

Criar `ai_usage_events` com os campos definidos na especificação: identidade, idempotência, provedor, ator, contextos de Orçamentos e Documental, resultado, tokens, requisições, unidades faturáveis, USD, BRL, snapshots, metadata, reserva e reconciliação. Aplicar checks para `actor_type`, `status`, métricas não negativas e JSON objeto.

Criar as tabelas administrativas com chaves UUID, `created_at`, `updated_at`, `created_by`, vigência e índices por período, serviço, usuário, modelo e status. Habilitar RLS em todas, revogar `public`, `anon` e `authenticated`, e conceder somente os privilégios necessários a `service_role`.

- [ ] **Step 4: Validar a migration**

Run: `node scripts/validate-sql-contract.mjs`
Expected: `Central AI usage SQL contract passed`.

Run: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202608010001_central_ai_usage_ledger.sql -f supabase/checks/central_ai_usage_contract.sql`
Expected: transação concluída e checks sem linhas de erro.

- [ ] **Step 5: Commit**

```bash
git add package.json scripts/validate-sql-contract.mjs supabase
git commit -m "feat: define central ai usage ledger"
```

### Task 3: Normalização, sanitização, preços e câmbio

**Files:**
- Create: `src/domain/usage.mjs`
- Create: `src/domain/pricing.mjs`
- Create: `test/usage.test.mjs`
- Create: `test/pricing.test.mjs`

**Interfaces:**
- Produces: `normalizeUsageEvent(input): NormalizedUsageEvent`, com identidade, serviço, origem, feature, provider/model, ator, contexto, status, métricas, duração, erro sanitizado e metadata allowlisted.
- Produces: `JsonScalar = string | number | boolean | null` e `sanitizeMetadata(input): Record<string, JsonScalar>`.
- Produces: `estimateCost({ usage, price, exchangeRate }): CostEstimate`, onde o resultado contém USD e BRL anuláveis e os dois snapshots usados.

- [ ] **Step 1: Escrever testes falhos de custo e segurança**

```js
test("calcula USD e BRL e preserva snapshots", () => {
  const result = estimateCost({
    usage: { input_tokens: 1000, output_tokens: 500, request_count: 1 },
    price: { input_per_million_usd: 1, output_per_million_usd: 2, source: "teste" },
    exchangeRate: { usd_brl: 5, source: "administrador" }
  });
  assert.equal(result.estimated_cost_usd, 0.002);
  assert.equal(result.estimated_cost_brl, 0.01);
});

test("remove conteúdo sensível", () => {
  assert.deepEqual(sanitizeMetadata({ feature_count: 2, prompt: "segredo", api_key: "x" }),
    { feature_count: 2 });
});
```

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/usage.test.mjs test/pricing.test.mjs`
Expected: FAIL porque os módulos ainda não existem.

- [ ] **Step 3: Implementar os módulos puros**

Reaproveitar de Etapa 3 os campos `input_per_million_usd`, `output_per_million_usd`, `per_request_usd` e `per_billable_unit_usd`. Aceitar somente métricas não negativas, normalizar e-mail para minúsculas, limitar textos e permitir metadata por allowlist. Retornar custo `null` quando uma dimensão usada não possuir tarifa.

- [ ] **Step 4: Executar os testes**

Run: `node --test test/usage.test.mjs test/pricing.test.mjs`
Expected: PASS para tokens, requisições, unidades faturáveis, custo ausente e sanitização.

- [ ] **Step 5: Commit**

```bash
git add src/domain test/usage.test.mjs test/pricing.test.mjs
git commit -m "feat: normalize and price central ai usage"
```

### Task 4: Políticas, reservas e transações atômicas

**Files:**
- Create: `src/domain/policies.mjs`
- Create: `test/policies.test.mjs`
- Create: `supabase/migrations/202608010002_ai_budget_control.sql`
- Create: `supabase/checks/ai_budget_control_contract.sql`

**Interfaces:**
- Produces: `evaluatePolicies({ policies, usageByPolicy, reservationBrl }): PolicyDecision`, com `allowed`, `blocking_policy_id`, `applied_policy_ids` e `alert_policy_ids`.
- Produces RPC: `reserve_ai_usage(jsonb) -> jsonb`.
- Produces RPC: `settle_ai_usage_reservation(uuid, jsonb) -> jsonb`.
- Produces RPC: `cancel_ai_usage_reservation(uuid, text) -> jsonb`.

- [ ] **Step 1: Escrever testes falhos das regras**

```js
test("a política mais restritiva bloqueia", () => {
  const decision = evaluatePolicies({
    policies: [
      { id: "global", alert_brl: 80, block_brl: 100 },
      { id: "module", alert_brl: 40, block_brl: 50 }
    ],
    usageByPolicy: new Map([["global", 30], ["module", 49]]),
    reservationBrl: 2
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.blocking_policy_id, "module");
});
```

Adicionar casos para alerta sem bloqueio, escopos global/serviço/usuário/modelo, exceção temporária, mês de São Paulo e ausência de política.

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/policies.test.mjs`
Expected: FAIL por módulo ausente.

- [ ] **Step 3: Implementar domínio e SQL**

Criar `ai_budget_policies`, `ai_budget_exceptions` e `ai_usage_reservations`. A RPC de reserva deve bloquear as políticas aplicáveis com `FOR UPDATE`, somar eventos liquidados e reservas ativas do mês, aplicar exceções vigentes e inserir a reserva na mesma transação. A liquidação deve ser idempotente, gravar o evento e mudar a reserva para `settled` uma única vez.

- [ ] **Step 4: Executar testes de domínio e contrato SQL**

Run: `node --test test/policies.test.mjs`
Expected: PASS.

Run: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202608010002_ai_budget_control.sql -f supabase/checks/ai_budget_control_contract.sql`
Expected: duas reservas concorrentes não ultrapassam o saldo e a segunda recebe `allowed=false`.

- [ ] **Step 5: Commit**

```bash
git add src/domain/policies.mjs test/policies.test.mjs supabase
git commit -m "feat: enforce atomic ai budget policies"
```

### Task 5: Credenciais de integração e API interna

**Files:**
- Create: `src/server/integration-auth.mjs`
- Create: `src/server/repository.mjs`
- Create: `src/server/internal-handlers.mjs`
- Create: `test/integration-auth.test.mjs`
- Create: `test/internal-handlers.test.mjs`
- Create: `app/api/internal/v1/reservations/route.ts`
- Create: `app/api/internal/v1/reservations/[id]/settle/route.ts`
- Create: `app/api/internal/v1/reservations/[id]/cancel/route.ts`
- Create: `app/api/internal/v1/events/route.ts`
- Create: `app/api/internal/v1/integrations/heartbeat/route.ts`

**Interfaces:**
- Consumes: RPCs da Task 4 e `normalizeUsageEvent` da Task 3.
- Produces: `authenticateIntegration(request, repository): IntegrationIdentity`, com `id`, `service`, `mode` e escopos permitidos.
- Produces: `createInternalHandlers({ repository, clock })`.

- [ ] **Step 1: Escrever testes falhos de autenticação e idempotência**

```js
test("recusa credencial de outro serviço", async () => {
  const response = await handlers.reserve(requestFor("documental", "orcamentos-secret"));
  assert.equal(response.status, 401);
});

test("liquidação repetida devolve o mesmo evento", async () => {
  const first = await handlers.settle(settleRequest);
  const second = await handlers.settle(settleRequest);
  assert.equal(first.body.event_id, second.body.event_id);
});
```

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/integration-auth.test.mjs test/internal-handlers.test.mjs`
Expected: FAIL por handlers ausentes.

- [ ] **Step 3: Implementar autenticação e handlers**

Usar o header `Authorization: Bearer ${AI_COST_CONTROL_KEY}`, armazenar apenas SHA-256 do segredo e comparar bytes com `timingSafeEqual`. Validar corpo com Zod, rejeitar campos sensíveis e limitar payload a 64 KiB. Respostas de bloqueio usam HTTP `409` com `code: "ai_budget_limit_reached"`; autenticação inválida usa `401`; evento duplicado retorna o registro existente com `200`.

- [ ] **Step 4: Executar testes e lint**

Run: `pnpm test && pnpm lint`
Expected: PASS; nenhum segredo aparece nos logs capturados pelos testes.

- [ ] **Step 5: Commit**

```bash
git add src/server app/api/internal test
git commit -m "feat: expose protected ai cost control api"
```

### Task 6: Login Microsoft e perfis administrativos

**Files:**
- Create: `src/server/auth/config.mjs`
- Create: `src/server/auth/microsoft.mjs`
- Create: `src/server/auth/session.mjs`
- Create: `src/server/auth/authorization.mjs`
- Create: `src/server/auth/handlers.mjs`
- Create: `test/auth.test.mjs`
- Create: `app/api/auth/microsoft/start/route.ts`
- Create: `app/api/auth/microsoft/callback/route.ts`
- Create: `app/api/auth/session/route.ts`
- Create: `app/api/auth/logout/route.ts`
- Create: `app/login/page.tsx`
- Create: `app/unauthorized.tsx`
- Create: `app/(admin)/layout.tsx`

**Interfaces:**
- Produces: `SessionState = { status: "anonymous" | "denied" | "authenticated"; user: AdminUser | null }`.
- Produces: `AdminUser = { id: string; email: string; name: string | null; role: "viewer" | "admin" }`.
- Produces: `getSession(requestHeaders): SessionState`, `requireAdminPage(headers): AdminUser` e `requireAdminApi(request, minimumRole): AdminUser`.

- [ ] **Step 1: Copiar e adaptar os testes de autenticação do Documental**

Cobrir estado OAuth assinado com prefixo `gestao-ia.`, callback em `/login`, cookie `HttpOnly; Secure; SameSite=Lax`, usuário não provisionado, `viewer`, `admin` e negação por padrão.

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/auth.test.mjs`
Expected: FAIL porque os módulos de auth não existem.

- [ ] **Step 3: Adaptar a implementação comprovada da Etapa 3**

Reutilizar a validação Microsoft e sessão do Documental, trocando somente base path, audience e repositório de autorização. Consultar `ai_admin_users` em toda criação de sessão. `viewer` pode usar GET/export; `admin` pode usar mutações. Redirecionamentos aceitam somente caminhos internos iniciados por `/gestao-ia/`.

- [ ] **Step 4: Executar testes e build**

Run: `node --test test/auth.test.mjs && pnpm build`
Expected: PASS; páginas privadas retornam login, `403` ou conteúdo conforme o perfil.

- [ ] **Step 5: Commit**

```bash
git add src/server/auth app/api/auth app/login app/unauthorized.tsx "app/(admin)/layout.tsx" test/auth.test.mjs
git commit -m "feat: protect ai cost administration with microsoft"
```

### Task 7: Consultas administrativas e API de gestão

**Files:**
- Create: `supabase/migrations/202608010003_ai_cost_dashboard.sql`
- Create: `src/server/admin-handlers.mjs`
- Create: `test/admin-handlers.test.mjs`
- Create: `app/api/admin/v1/dashboard/route.ts`
- Create: `app/api/admin/v1/events/route.ts`
- Create: `app/api/admin/v1/events/export/route.ts`
- Create: `app/api/admin/v1/policies/route.ts`
- Create: `app/api/admin/v1/prices/route.ts`
- Create: `app/api/admin/v1/exchange-rates/route.ts`
- Create: `app/api/admin/v1/exceptions/route.ts`
- Create: `app/api/admin/v1/integrations/route.ts`
- Create: `app/api/admin/v1/audit/route.ts`

**Interfaces:**
- Produces RPC: `ai_cost_dashboard(filters jsonb) -> jsonb`.
- Produces: `createAdminHandlers({ repository, notifier, clock })`.

- [ ] **Step 1: Escrever testes falhos do dashboard e das permissões**

```js
test("viewer consulta mas não altera limite", async () => {
  assert.equal((await handlers.dashboard(viewerRequest)).status, 200);
  assert.equal((await handlers.savePolicy(viewerMutation)).status, 403);
});

test("dashboard separa gasto liquidado e reservado", async () => {
  const result = await handlers.dashboard(adminRequest);
  assert.deepEqual(result.body.totals, {
    settled_brl: 80,
    reserved_brl: 10,
    available_brl: 10,
    unpriced_calls: 1
  });
});
```

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/admin-handlers.test.mjs`
Expected: FAIL por handler ausente.

- [ ] **Step 3: Implementar RPC, repository e handlers**

A RPC deve devolver totais, evolução diária, comparação com mês anterior, projeção linear, agrupamentos por serviço/usuário/feature/provider/model, políticas efetivas, eventos paginados e contagem de chamadas sem preço. Toda mutação grava `ai_audit_log` com ator, antes, depois e justificativa.

- [ ] **Step 4: Executar testes e SQL checks**

Run: `node --test test/admin-handlers.test.mjs && pnpm lint`
Expected: PASS.

Run: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202608010003_ai_cost_dashboard.sql`
Expected: função criada com execução concedida somente a `service_role`.

- [ ] **Step 5: Commit**

```bash
git add supabase src/server/admin-handlers.mjs app/api/admin test/admin-handlers.test.mjs
git commit -m "feat: add central ai cost administration api"
```

### Task 8: Shell, visão geral, consumo e eventos

**Files:**
- Create: `components/admin-shell.tsx`
- Create: `components/overview-dashboard.tsx`
- Create: `components/usage-filters.tsx`
- Create: `components/usage-trend.tsx`
- Create: `components/usage-breakdowns.tsx`
- Create: `components/events-table.tsx`
- Create: `app/lib/admin-api.ts`
- Create: `app/(admin)/page.tsx`
- Create: `app/(admin)/consumo/page.tsx`
- Create: `app/(admin)/eventos/page.tsx`
- Create: `test/admin-ui-contract.test.mjs`

**Interfaces:**
- Consumes: API administrativa da Task 7 e `withBasePath` da Task 1.
- Produces: navegação e telas de consulta responsivas.

- [ ] **Step 1: Escrever teste falho do contrato visual**

Verificar no código renderizado as áreas `Visão geral`, `Consumo`, `Eventos`, `Limites`, `Preços e câmbio`, `Integrações` e `Auditoria`; os indicadores `Custo estimado`, `Saldo disponível`, `Chamadas`, `Tokens`, `Erros` e `Sem preço`; e ausência das palavras sem acento equivalentes.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node --test test/admin-ui-contract.test.mjs`
Expected: FAIL por componentes ausentes.

- [ ] **Step 3: Implementar interface reaproveitando os painéis existentes**

Adaptar `usage-dashboard.tsx` da Etapa 3 e os gráficos Recharts da Etapa 2. Manter navegação lateral compacta, ícones Lucide com tooltip, cards de indicador sem aninhamento, tabelas com overflow local e filtros responsivos. Exibir BRL como valor principal e USD como detalhe.

Adicionar `Exportar CSV` na tela de eventos. A ação usa os filtros aplicados, exige sessão válida, limita o intervalo a 366 dias e grava auditoria sem registrar o conteúdo exportado.

- [ ] **Step 4: Validar interface**

Run: `node --test test/admin-ui-contract.test.mjs && pnpm lint && pnpm build`
Expected: PASS e build standalone concluído.

- [ ] **Step 5: Commit**

```bash
git add components app/lib "app/(admin)" test/admin-ui-contract.test.mjs
git commit -m "feat: add central ai cost dashboards"
```

### Task 9: Limites, preços, câmbio, integrações e auditoria

**Files:**
- Create: `components/policy-editor.tsx`
- Create: `components/price-editor.tsx`
- Create: `components/exchange-rate-editor.tsx`
- Create: `components/integration-status.tsx`
- Create: `components/audit-table.tsx`
- Create: `app/(admin)/limites/page.tsx`
- Create: `app/(admin)/precos/page.tsx`
- Create: `app/(admin)/integracoes/page.tsx`
- Create: `app/(admin)/auditoria/page.tsx`
- Create: `test/admin-settings-ui.test.mjs`

**Interfaces:**
- Consumes: mutações da Task 7.
- Produces: formulários exclusivos de `admin` com justificativa obrigatória.

- [ ] **Step 1: Escrever testes falhos de validação dos formulários**

Cobrir alerta menor que bloqueio, valores não negativos, vigência de exceção, tarifa por unidade, cotação positiva, confirmação de desbloqueio e justificativa obrigatória.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node --test test/admin-settings-ui.test.mjs`
Expected: FAIL por validadores ausentes.

- [ ] **Step 3: Implementar validadores e telas**

Usar inputs monetários, selects de escopo, data/hora para exceção e confirmação explícita nas ações críticas. Exibir a política efetiva e o consumo atual antes de salvar. Desabilitar mutações para `viewer` no servidor e na interface.

- [ ] **Step 4: Executar testes e build**

Run: `node --test test/admin-settings-ui.test.mjs && pnpm build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add components "app/(admin)" test/admin-settings-ui.test.mjs
git commit -m "feat: manage ai budgets and pricing"
```

### Task 10: Alertas no painel e por e-mail

**Files:**
- Create: `supabase/migrations/202608010004_ai_alert_outbox.sql`
- Create: `src/server/alerts.mjs`
- Create: `scripts/dispatch-alerts.mjs`
- Create: `test/alerts.test.mjs`
- Modify: `src/server/internal-handlers.mjs`
- Modify: `.env.example`
- Modify: `package.json`

**Interfaces:**
- Produces: `enqueueThresholdAlerts(decision, context, repository): Promise<void>`.
- Produces: `dispatchPendingAlerts({ repository, graphClient }): Promise<DispatchSummary>`, onde `DispatchSummary = { claimed: number; sent: number; failed: number; pending: number }`.

- [ ] **Step 1: Escrever testes falhos de deduplicação e tolerância**

```js
test("emite um alerta por política e período", async () => {
  await enqueueThresholdAlerts(decision, context, repository);
  await enqueueThresholdAlerts(decision, context, repository);
  assert.equal(repository.alerts.length, 1);
});

test("falha de e-mail mantém o alerta pendente", async () => {
  const result = await dispatchPendingAlerts({ repository, graphClient: failingGraph });
  assert.equal(result.pending, 1);
});
```

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/alerts.test.mjs`
Expected: FAIL por módulo ausente.

- [ ] **Step 3: Implementar outbox e envio Microsoft Graph**

Criar unicidade `(policy_id, period_key, threshold_type)`. Enviar e-mail via Microsoft Graph com credenciais de aplicação `MICROSOFT_TENANT_ID`, `AI_ALERT_CLIENT_ID`, `AI_ALERT_CLIENT_SECRET` e `AI_ALERT_SENDER_EMAIL`. A aplicação de alerta precisa de permissão Microsoft Graph `Mail.Send` concedida por administrador e não reutiliza o segredo da sessão OAuth. Persistir somente destinatário, assunto, estado, tentativas e erro sanitizado. A liquidação nunca falha por causa do envio.

- [ ] **Step 4: Executar testes**

Run: `node --test test/alerts.test.mjs test/internal-handlers.test.mjs`
Expected: PASS para deduplicação, retry e falha tolerada.

- [ ] **Step 5: Commit**

```bash
git add supabase src/server/alerts.mjs src/server/internal-handlers.mjs scripts/dispatch-alerts.mjs test/alerts.test.mjs .env.example package.json
git commit -m "feat: notify administrators about ai spend"
```

### Task 11: Docker, saúde e verificação ponta a ponta

**Files:**
- Create: `infra/docker/Dockerfile`
- Create: `app/api/health/route.ts`
- Create: `playwright.config.ts`
- Create: `e2e/gestao-ia.spec.ts`
- Create: `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`
- Create: `scripts/verify-production.mjs`
- Modify: `package.json`

**Interfaces:**
- Produces: imagem que escuta em `3000` e health check `/gestao-ia/api/health`.
- Produces: comandos `pnpm test:e2e` e `pnpm verify:production`.

- [ ] **Step 1: Escrever os testes E2E**

Cobrir login, acesso negado, visão geral, filtros, criação de limite, exceção temporária, evento bloqueado, layout em `1440x900` e `390x844`, e navegação sem caminhos fora de `/gestao-ia/`.

- [ ] **Step 2: Executar e confirmar a falha antes do servidor completo**

Run: `pnpm exec playwright test e2e/gestao-ia.spec.ts`
Expected: FAIL até a imagem e as variáveis de teste estarem configuradas.

- [ ] **Step 3: Criar imagem standalone, health e runbook**

O Dockerfile deve executar build multi-stage com Node 20 Alpine, copiar `.next/standalone`, `.next/static` e `public`, definir `PORT=3000`, `HOSTNAME=0.0.0.0`, `APP_BASE_PATH=/gestao-ia` e expor `3000`. O health verifica processo, banco e migrations sem retornar segredos.

- [ ] **Step 4: Executar a matriz final**

Run: `pnpm test && pnpm lint && pnpm build`
Expected: todos passam.

Run: `docker build -f infra/docker/Dockerfile -t solutiongroup-gestao-ia:test .`
Expected: imagem criada.

Run: `pnpm exec playwright test`
Expected: desktop e mobile passam, sem erros de console, requests 404 ou sobreposição.

- [ ] **Step 5: Commit**

```bash
git add infra app/api/health playwright.config.ts e2e docs scripts/verify-production.mjs package.json
git commit -m "chore: prepare central ai cost platform deployment"
```
