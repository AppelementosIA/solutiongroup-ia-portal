# Integrações da gestão central de custos de IA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar Orçamentos e Documental à plataforma central com reserva antes da chamada, liquidação depois da chamada, ledger local preservado e reenvio idempotente.

**Architecture:** Cada projeto recebe um adaptador pequeno para o contrato HTTP v1 e uma outbox local. O adaptador consulta a central antes de operações pagas, mas trabalha em `fail-open` se a central estiver indisponível; eventos e liquidações pendentes são reconciliados depois sem duplicação.

**Tech Stack:** TypeScript/Express no Orçamentador, JavaScript/Next.js e Python no Documental, Supabase/PostgreSQL, node:test, validadores `.mts` e unittest/pytest.

## Global Constraints

- Depende da conclusão das Tasks 1 a 7 do plano da plataforma central.
- Primeiros módulos: `orcamentos`, `documental-web` e `documental-worker`.
- Não alterar Relatórios, Erosão ou outros serviços.
- Manter os ledgers locais durante toda a implantação gradual.
- Nunca enviar prompt, resposta, documento, token de acesso ou segredo à central.
- Bloqueio deve ocorrer antes da chamada ao provedor.
- Indisponibilidade central deve ser `fail-open` e gerar pendência local.
- Resposta de bloqueio deve usar `ai_budget_limit_reached` e português natural.
- Todo envio precisa de `source_event_id` e `idempotency_key` estáveis.

---

### Task 1: Congelar o contrato HTTP v1 e seus fixtures

**Files (repo `solutiongroup-ia-gestao`):**
- Create: `contracts/ai-cost-control-v1.schema.json`
- Create: `contracts/examples/reservation-request.json`
- Create: `contracts/examples/reservation-allowed.json`
- Create: `contracts/examples/reservation-blocked.json`
- Create: `contracts/examples/settlement-request.json`
- Create: `contracts/examples/event-request.json`
- Create: `test/contracts.test.mjs`
- Create: `docs/AI_COST_CONTROL_V1.md`

**Interfaces:**
- Produces: contrato compartilhado por TypeScript, JavaScript e Python.
- Produces: códigos `allowed`, `ai_budget_limit_reached`, `integration_unavailable` e `invalid_usage_event`.

- [ ] **Step 1: Escrever o teste falho dos exemplos**

```js
import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import Ajv2020 from "ajv/dist/2020.js";

const schema = JSON.parse(await readFile(new URL("../contracts/ai-cost-control-v1.schema.json", import.meta.url)));
const fixtures = await Promise.all([
  "reservation-request",
  "reservation-allowed",
  "reservation-blocked",
  "settlement-request",
  "event-request"
].map(async (name) => ({
  name,
  payload: JSON.parse(await readFile(new URL(`../contracts/examples/${name}.json`, import.meta.url)))
})));
const validate = new Ajv2020({ strict: true }).compile(schema);

for (const fixture of fixtures) {
  test(`${fixture.name} respeita o schema v1`, () => {
    assert.equal(validate(fixture.payload), true, JSON.stringify(validate.errors));
  });
}
```

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node --test test/contracts.test.mjs`
Expected: FAIL porque schema e fixtures não existem.

- [ ] **Step 3: Criar schema e exemplos completos**

O pedido de reserva deve conter `service`, `source`, `feature`, `provider`, `model`, `actor`, `context`, `estimated_max_cost_usd`, `estimated_max_cost_brl` e `idempotency_key`. A resposta autorizada contém `allowed: true`, `reservation_id`, `reserved_brl` e políticas aplicadas. A resposta bloqueada contém `allowed: false`, `code`, mensagem, escopo e limite, sem revelar consumo de outros usuários.

A liquidação contém `reservation_id`, `source_event_id`, status, métricas, duração, erro sanitizado e metadata allowlisted. Evento sem reserva usa o mesmo corpo sem `reservation_id`.

- [ ] **Step 4: Validar contrato e documentação**

Run: `node --test test/contracts.test.mjs`
Expected: todos os exemplos passam pelo JSON Schema draft 2020-12.

- [ ] **Step 5: Commit**

```bash
git add contracts test/contracts.test.mjs docs/AI_COST_CONTROL_V1.md
git commit -m "docs: publish ai cost control contract"
```

### Task 2: Cliente, IDs e outbox no Orçamentador

**Files (repo Elementus Etapa 2, branch `solutiongroup-orcamentos`):**
- Create: `apps/api/src/lib/central-ai-cost-core.ts`
- Create: `apps/api/src/lib/central-ai-cost.ts`
- Create: `infra/supabase/migrations/20260801_orc_ai_cost_outbox.sql`
- Create: `scripts/validate_central_ai_cost_control.mts`
- Modify: `apps/api/src/lib/config.ts`
- Modify: `apps/api/src/lib/ai-usage.ts`
- Modify: `.env.example`
- Modify: `package.json`

**Interfaces:**
- Produces: `reserveCentralAiCost(input): Promise<ReservationResult>`.
- Produces: `DeliveryResult = { mode: "delivered"; eventId: string } | { mode: "queued"; outboxId: string }` e `settleCentralAiCost(input): Promise<DeliveryResult>`.
- Produces: `FlushSummary = { claimed: number; delivered: number; failed: number }` e `flushCentralAiCostOutbox(limit): Promise<FlushSummary>`.
- Modifica: `recordAiUsageEvent` passa a aceitar `eventId` e devolve `{ recorded, eventId }`.

- [ ] **Step 1: Escrever o validador falho**

Cobrir: URL normalizada, timeout de 2 segundos, `fail-open`, resposta bloqueada, `crypto.randomUUID()` estável por tentativa, payload sanitizado e inserção em outbox quando reserve/settle falhar.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `pnpm validate:central-ai-cost`
Expected: FAIL porque os módulos e o script ainda não existem.

- [ ] **Step 3: Implementar core e migration**

```ts
export type ReservationResult =
  | { mode: "reserved"; reservationId: string; reservedBrl: number }
  | { mode: "blocked"; code: "ai_budget_limit_reached"; message: string }
  | { mode: "bypass"; reason: "central_unavailable" };
```

Criar `orc_ai_cost_outbox` com `id`, `operation`, `idempotency_key`, `payload`, `attempts`, `available_at`, `last_error_code`, `delivered_at` e unicidade por operação/chave. RLS sem policies de cliente e acesso exclusivo de service role.

Adicionar a `config.ts`: `AI_COST_CONTROL_URL`, `AI_COST_CONTROL_KEY`, `AI_COST_CONTROL_TIMEOUT_MS=2000` e `AI_COST_CONTROL_ENABLED=false`. Nunca registrar a chave.

- [ ] **Step 4: Executar validações existentes e novas**

Run: `pnpm validate:central-ai-cost && pnpm validate:ai-usage && pnpm build:api`
Expected: PASS e nenhuma alteração no cálculo local existente.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/lib infra/supabase/migrations scripts/validate_central_ai_cost_control.mts .env.example package.json
git commit -m "feat: add central ai cost client to budgets"
```

### Task 3: Reserva e liquidação na sugestão de preços do Orçamentador

**Files (repo Elementus Etapa 2):**
- Modify: `apps/api/src/routes/budgets.ts`
- Modify: `scripts/validate_central_ai_cost_control.mts`

**Interfaces:**
- Consumes: cliente da Task 2.
- Produces: bloqueio HTTP `429` antes de `requestOpenAiWebPriceSuggestion`.

- [ ] **Step 1: Adicionar teste falho da ordem das operações**

O validador deve provar a ordem `reserve -> provider -> local ledger -> settle`, que `blocked` não chama o provider e que `bypass` chama o provider e cria outbox após o evento.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `pnpm validate:central-ai-cost`
Expected: FAIL indicando ausência da reserva na rota.

- [ ] **Step 3: Integrar a rota existente**

Antes do bloco que chama `requestOpenAiWebPriceSuggestion`, criar `eventId`, estimar a reserva pelo modelo e tarifa configurados e chamar `reserveCentralAiCost`. Em `blocked`, retornar:

```json
{
  "code": "ai_budget_limit_reached",
  "error": "O limite mensal de consumo de IA foi atingido. Procure o administrador da plataforma para solicitar uma liberação."
}
```

Nos caminhos de sucesso e erro, usar o mesmo `eventId`, preservar `recordAiUsageEvent` e liquidar ou enfileirar o evento central sem alterar a resposta principal.

- [ ] **Step 4: Executar regressão do Orçamentador**

Run: `pnpm validate:central-ai-cost && pnpm validate:ai-usage && pnpm validate:orcamentos-boundary && pnpm build`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api/src/routes/budgets.ts scripts/validate_central_ai_cost_control.mts
git commit -m "feat: enforce ai budget on price suggestions"
```

### Task 4: Cliente e outbox no servidor web do Documental

**Files (repo Elementus Etapa 3, branch `solutiongroup-documental`):**
- Create: `apps/web/src/server/central-ai-cost.mjs`
- Create: `apps/web/test/central-ai-cost.test.mjs`
- Create: `supabase/migrations/202608010005_documental_ai_cost_outbox.sql`
- Modify: `apps/web/src/server/ai-usage.mjs`
- Modify: `apps/web/src/server/supabase-repository.mjs`
- Modify: `apps/web/.env.example`

**Interfaces:**
- Produces: `createAiCostGuard({ repository, env, fetchImpl, clock })`.
- Produces: `guard.reserve(context)`, `guard.settle(reservation, event)` e `guard.cancel(reservation, reason)`.
- Produces repository: `enqueueAiCostOperation(row)` e `claimAiCostOutbox(limit)`.

- [ ] **Step 1: Escrever testes falhos do guard**

Repetir fixtures do contrato v1 e cobrir timeout, bloqueio, bypass, sanitização, evento de usuário, evento de sistema e liquidação idempotente.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node --test apps/web/test/central-ai-cost.test.mjs`
Expected: FAIL por módulo ausente.

- [ ] **Step 3: Implementar cliente e outbox**

Usar `AbortSignal.timeout(Number(env.AI_COST_CONTROL_TIMEOUT_MS || 2000))`. O cliente fica desligado quando `AI_COST_CONTROL_ENABLED !== "true"`. Segredos ficam apenas no servidor. A outbox possui o mesmo contrato de estados do Orçamentador e acesso exclusivo de service role.

Modificar `recordAiUsageSafely` para aceitar `event_id` gerado antes do provider e retornar o row normalizado para liquidação, mantendo compatibilidade com chamadas atuais.

- [ ] **Step 4: Executar testes do Documental web**

Run: `node --test apps/web/test/central-ai-cost.test.mjs apps/web/test/ai-usage.test.mjs apps/web/test/api-auth-boundary.test.mjs`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/server apps/web/test/central-ai-cost.test.mjs apps/web/.env.example supabase/migrations
git commit -m "feat: add central ai cost guard to documental web"
```

### Task 5: Aplicar o guard às operações web do Documental

**Files (repo Elementus Etapa 3):**
- Modify: `apps/web/src/server/handlers.mjs`
- Modify: `apps/web/src/server/supabase-repository.mjs`
- Modify: `apps/web/test/handlers.test.mjs`
- Modify: `apps/web/test/ai-usage.test.mjs`

**Interfaces:**
- Consumes: `createAiCostGuard` da Task 4.
- Produces: reserva e liquidação para chat, busca/embedding web e operações disparadas pelo servidor.

- [ ] **Step 1: Escrever testes falhos por funcionalidade**

Para cada feature web já registrada no ledger, provar: bloqueio antes do provider; um `source_event_id`; liquidação no sucesso; liquidação de erro sanitizado; e bypass com outbox na indisponibilidade.

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test apps/web/test/handlers.test.mjs apps/web/test/ai-usage.test.mjs`
Expected: pelo menos o cenário bloqueado falha porque o provider ainda é chamado.

- [ ] **Step 3: Envolver as chamadas pagas**

Criar um helper local `runWithAiCostGuard` que recebe contexto, função do provider e normalizador de uso. Não alterar prompts, respostas nem decisões de negócio. Traduzir bloqueio para HTTP `429` e a mesma mensagem em português do Orçamentador.

- [ ] **Step 4: Executar regressão web**

Run: `node --test apps/web/test/*.test.mjs && pnpm --filter @elementus/web build`
Expected: todas as suites passam.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/server/handlers.mjs apps/web/src/server/supabase-repository.mjs apps/web/test
git commit -m "feat: enforce ai budgets in documental web"
```

### Task 6: Cliente, reserva e outbox no worker do Documental

**Files (repo Elementus Etapa 3):**
- Create: `services/worker/copiloto_worker/ai_cost_control.py`
- Create: `services/worker/tests/test_ai_cost_control.py`
- Modify: `services/worker/copiloto_worker/config.py`
- Modify: `services/worker/copiloto_worker/app.py`
- Modify: `services/worker/copiloto_worker/core.py`
- Modify: `services/worker/copiloto_worker/ai_usage.py`
- Modify: `services/worker/copiloto_worker/supabase_store.py`
- Modify: `services/worker/.env.example`

**Interfaces:**
- Produces: `AiCostControlClient.reserve(context) -> ReservationDecision`.
- Produces: `settle_safely(reservation, event) -> bool` e `flush_outbox(limit) -> FlushSummary`.
- Produces: `run_guarded_ai_operation(client, provider_call, context) -> OperationResult`, onde `OperationResult` contém `status`, `reservation_id`, `value` ou erro sanitizado e nunca inclui conteúdo documental.

- [ ] **Step 1: Escrever testes falhos em Python**

```python
def test_blocked_reservation_skips_provider():
    client = FakeAiCostClient(blocked=True)
    provider = SpyProvider()
    result = run_guarded_operation(client, provider.call, valid_context())
    assert result.code == "ai_budget_limit_reached"
    assert provider.calls == 0
```

Adicionar timeout/bypass, ator `system`, units/pages, retry de outbox e ausência de conteúdo documental.

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `python -m unittest services.worker.tests.test_ai_cost_control -v`
Expected: FAIL por módulo ausente.

- [ ] **Step 3: Implementar e integrar**

Usar biblioteca HTTP já presente no worker; timeout padrão de 2 segundos. Envolver classificação, embeddings de ingestão, OCR Azure e rerank Cohere nos mesmos pontos que hoje chamam `AiUsageRecorder.record_safely`. Persistir operações pendentes pela `SupabaseJobStore` e usar `InMemoryJobStore` nos testes.

- [ ] **Step 4: Executar regressão do worker**

Run: `python -m unittest services.worker.tests.test_ai_cost_control services.worker.tests.test_ai_usage services.worker.tests.test_worker -v`
Expected: PASS.

Run: `python -m unittest discover -s services/worker/tests -v`
Expected: suite completa passa.

- [ ] **Step 5: Commit**

```bash
git add services/worker/copiloto_worker services/worker/tests/test_ai_cost_control.py services/worker/.env.example
git commit -m "feat: enforce ai budgets in documental worker"
```

### Task 7: Importação histórica e reconciliação

**Files (repo `solutiongroup-ia-gestao`):**
- Create: `scripts/import-orcamentos-usage.mjs`
- Create: `scripts/import-documental-usage.mjs`
- Create: `scripts/reconcile-usage-source.mjs`
- Create: `test/import-usage.test.mjs`
- Modify: `.env.example`
- Modify: `package.json`
- Modify: `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`

**Interfaces:**
- Produces: scripts `import:orcamentos`, `import:documental` e `reconcile:usage`.
- Produces: relatório JSON por fonte com linhas lidas, inseridas, duplicadas, sem preço e divergências.

- [ ] **Step 1: Escrever testes falhos com fixtures dos dois ledgers**

Cobrir mapeamento de proposta/item e conversa/documento/job, preservação de timestamp e USD, BRL nulo sem cotação histórica e repetição idempotente da importação.

- [ ] **Step 2: Executar e confirmar as falhas**

Run: `node --test test/import-usage.test.mjs`
Expected: FAIL por importadores ausentes.

- [ ] **Step 3: Implementar paginação e reconciliação**

Ler as fontes com service role em lotes de 500, mapear para o contrato central, usar ID original como `source_event_id` e inserir com `on conflict do nothing`. Comparar por dia, serviço, provider/model, chamadas, tokens e USD. Nunca escrever nas tabelas de origem. Usar variáveis server-side `ORCAMENTOS_SUPABASE_URL`, `ORCAMENTOS_SUPABASE_SERVICE_ROLE_KEY`, `DOCUMENTAL_SUPABASE_URL` e `DOCUMENTAL_SUPABASE_SERVICE_ROLE_KEY`.

- [ ] **Step 4: Executar em ambiente de homologação**

Run: `pnpm import:orcamentos -- --dry-run && pnpm import:documental -- --dry-run`
Expected: relatórios sem escrita e sem campos sensíveis.

Run: `pnpm reconcile:usage -- --from=2026-07-01 --to=2026-08-02`
Expected: totais centrais iguais às fontes, exceto diferenças explicitamente classificadas como `unpriced`.

- [ ] **Step 5: Commit**

```bash
git add scripts test/import-usage.test.mjs .env.example package.json docs/EASYPANEL_GESTAO_IA_RUNBOOK.md
git commit -m "feat: import and reconcile ai usage ledgers"
```

### Task 8: Matriz de ativação gradual

**Files (três repos):**
- Create: `docs/AI_COST_CONTROL_ROLLOUT.md` no repo central.
- Modify: `.env.example` nos repos Orçamentos e Documental.
- Create: `scripts/verify-ai-cost-integration.mjs` no repo central.
- Create: `test/integration-rollout.test.mjs` no repo central.

**Interfaces:**
- Produces: estados `disabled`, `report_only`, `alerting` e `enforcing` por integração.
- Produces: verificador ponta a ponta sem chamar um provedor pago.

- [ ] **Step 1: Escrever teste falho da matriz de estados**

Provar que `disabled` não chama a central, `report_only` nunca bloqueia, `alerting` cria alertas sem bloquear e `enforcing` respeita `ai_budget_limit_reached`.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `node --test test/integration-rollout.test.mjs`
Expected: FAIL até o estado estar no contrato e nos adaptadores.

- [ ] **Step 3: Implementar estado configurável e verificador**

O heartbeat publica modo, versão e última sincronização. O verificador cria uma reserva sintética marcada `metadata.test=true`, liquida, consulta o evento e remove apenas o fixture de teste pela rotina administrativa controlada.

- [ ] **Step 4: Executar validações dos três projetos**

Run central: `pnpm test && pnpm build`

Run Orçamentos: `pnpm validate:central-ai-cost && pnpm validate:ai-usage && pnpm build`

Run Documental: `node --test apps/web/test/*.test.mjs && python -m unittest discover -s services/worker/tests -v && pnpm --filter @elementus/web build`

Expected: todas passam antes de qualquer modo `enforcing`.

- [ ] **Step 5: Commit em cada repositório**

```bash
git add docs scripts test .env.example
git commit -m "docs: define ai cost control rollout"
```
