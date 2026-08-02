# Publicação da gestão central de custos de IA Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar a plataforma central no GitHub e EasyPanel, conectar `/gestao-ia/`, atualizar a ponte Microsoft e adicionar o card ao portal somente após validação.

**Architecture:** O novo serviço roda isolado no EasyPanel e recebe exclusivamente o prefixo `/gestao-ia/` do domínio existente. O portal Nginx continua servindo a raiz e atua somente como ponte do callback Microsoft em `/login`; a ativação dos módulos ocorre por flags graduais.

**Tech Stack:** GitHub, Docker, EasyPanel, Supabase/PostgreSQL, Nginx, Microsoft OAuth, PowerShell, Playwright e HTTP smoke tests.

## Global Constraints

- Não alterar DNS nem o domínio `https://ia.solutiongroup.com.br/`.
- Não substituir `solutiongroup-ia`, `solutiongroup-orcamentos`, `solutiongroup-documental`, `solutiongroup-relatorios` ou `solutiongroup-erosao`.
- Criar somente o serviço `solutiongroup-gestao-ia`.
- Porta interna do novo serviço: `3000`.
- Rota pública exata: `https://ia.solutiongroup.com.br/gestao-ia/`.
- O card do portal deve usar exclusivamente `/gestao-ia/`.
- A ponte `/login` deve continuar preservando query OAuth, HTTPS, `no-store`, `no-referrer` e ausência de logs.
- Não ativar `enforcing` antes de importação, gravação dupla e reconciliação aprovadas.

---

### Task 1: Criar e publicar o repositório central

**Files (repo local `solutiongroup-ia-gestao`):**
- Verify: todos os arquivos do plano da plataforma.
- Create: `README.md`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `AppelementosIA/solutiongroup-ia-gestao`, branch `main`.
- Produces: CI com testes, lint e build.

- [ ] **Step 1: Criar README e workflow CI**

O README deve registrar URL, arquitetura, variáveis por categoria, comandos locais, migrations, modos de rollout e links para os runbooks. O workflow usa Node 20, pnpm 9, cache do pnpm e executa `pnpm test`, `pnpm lint` e `pnpm build` sem segredos de produção.

- [ ] **Step 2: Executar a matriz local**

Run: `pnpm test && pnpm lint && pnpm build`
Expected: código `0` em todos os comandos.

Run: `git switch main && git merge --ff-only codex/gestao-ia-platform`
Expected: `main` aponta para o mesmo commit validado da branch de implementação.

- [ ] **Step 3: Criar o repositório GitHub privado**

Run: `gh repo create AppelementosIA/solutiongroup-ia-gestao --private --source . --remote origin`
Expected: repositório criado com `origin` apontando para a organização correta.

- [ ] **Step 4: Commit e push**

```bash
git add README.md .github/workflows/ci.yml
git commit -m "docs: document central ai cost platform"
git push -u origin main
```

Expected: workflow verde no GitHub.

- [ ] **Step 5: Registrar evidência**

Run: `gh run list --limit 1`
Expected: execução `completed` e `success` para `main`.

### Task 2: Provisionar o banco central e segredos

**Files (repo central):**
- Modify: `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`
- Create: `docs/PRODUCTION_ENV_MATRIX.md`
- Create: `docs/PRODUCTION_DATABASE_EVIDENCE.json`

**Interfaces:**
- Produces: banco dedicado da gestão de IA com migrations aplicadas.
- Produces: usuário administrador inicial e credenciais distintas para cada integração.

- [ ] **Step 1: Criar o projeto central no Supabase**

Nome: `solutiongroup-gestao-ia`. Região: a mesma dos módulos existentes. Guardar URL e service role somente no gerenciador de segredos do EasyPanel; nunca versionar valores.

- [ ] **Step 2: Aplicar migrations e checks**

Run: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/migrations/202608010001_central_ai_usage_ledger.sql -f supabase/migrations/202608010002_ai_budget_control.sql -f supabase/migrations/202608010003_ai_cost_dashboard.sql -f supabase/migrations/202608010004_ai_alert_outbox.sql`
Expected: todas as migrations concluem.

Run: `psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/checks/central_ai_usage_contract.sql -f supabase/checks/ai_budget_control_contract.sql`
Expected: RLS, grants, constraints e RPCs passam.

- [ ] **Step 3: Provisionar acesso e integrações**

Inserir `elm.ia@elementus-sa.com.br` como `admin`. Gerar três segredos aleatórios de pelo menos 32 bytes, armazenar apenas SHA-256 em `ai_integrations` para `orcamentos`, `documental-web` e `documental-worker`; guardar os valores originais somente nos secrets dos serviços correspondentes.

- [ ] **Step 4: Configurar preços e câmbio inicial**

Importar as tarifas versionadas existentes em `AI_USAGE_PRICING_JSON` dos dois módulos, sem alterar valores. Registrar uma cotação USD/BRL de vigência atual com fonte e usuário administrador. Modelos sem preço permanecem identificados como `unpriced` e sem bloqueio. Provisionar separadamente a aplicação Microsoft Graph de alertas com permissão administrativa `Mail.Send`; ela não altera o app registration usado no login.

- [ ] **Step 5: Gravar evidência sanitizada**

`PRODUCTION_DATABASE_EVIDENCE.json` deve conter timestamp, hashes das migrations, tabelas/RPCs verificadas e contagens, sem URL, chaves ou e-mails adicionais.

### Task 3: Criar o serviço `solutiongroup-gestao-ia` no EasyPanel

**Files (repo central):**
- Modify: `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`
- Create: `docs/EASYPANEL_PUBLICATION_EVIDENCE.json`

**Interfaces:**
- Produces: container Git/Dockerfile na porta `3000`.
- Produces: health interno e externo.

- [ ] **Step 1: Criar o serviço sem rota pública**

No projeto `solutiongroup`, criar app `solutiongroup-gestao-ia`, fonte Git `AppelementosIA/solutiongroup-ia-gestao`, branch `main`, Dockerfile `infra/docker/Dockerfile`, contexto raiz e porta `3000`.

- [ ] **Step 2: Configurar variáveis**

Definir `NODE_ENV=production`, `PORT=3000`, `APP_BASE_PATH=/gestao-ia`, `NEXT_PUBLIC_APP_BASE_PATH=/gestao-ia`, Supabase server-side, Microsoft auth, chave de sessão, integração de e-mail e destinatários. Não configurar segredos com prefixo `NEXT_PUBLIC_`.

- [ ] **Step 3: Implantar e verificar logs**

Expected: build standalone concluído, processo escutando em `0.0.0.0:3000`, migrations compatíveis e nenhum segredo impresso.

- [ ] **Step 4: Testar health pela rede interna**

Run dentro do EasyPanel: `wget -qO- http://solutiongroup-gestao-ia:3000/gestao-ia/api/health`
Expected: HTTP `200` e JSON com `status: "ok"`, banco `ok` e versão da migration.

- [ ] **Step 5: Registrar evidência**

Salvar commit implantado, image digest, horário, health e configuração não sensível em `docs/EASYPANEL_PUBLICATION_EVIDENCE.json` e fazer commit:

```bash
git add docs/EASYPANEL_GESTAO_IA_RUNBOOK.md docs/EASYPANEL_PUBLICATION_EVIDENCE.json
git commit -m "docs: record ai cost platform deployment"
git push
```

### Task 4: Publicar `/gestao-ia/` e validar Microsoft 365

**Files (repo central):**
- Modify: `docs/EASYPANEL_PUBLICATION_EVIDENCE.json`
- Modify: `docs/EASYPANEL_GESTAO_IA_RUNBOOK.md`

**Interfaces:**
- Produces: rota pública exata no domínio existente.
- Consumes: callback central `https://ia.solutiongroup.com.br/login`.

- [ ] **Step 1: Adicionar rota de domínio no novo serviço**

Configurar `ia.solutiongroup.com.br` com path `/gestao-ia` apontando para porta `3000`, preservando HTTPS e sem remover as rotas dos outros serviços. A rota por prefixo deve ter prioridade sobre o catch-all `/` do portal.

- [ ] **Step 2: Verificar conteúdo e assets sem autenticação**

Run: `curl.exe -I "https://ia.solutiongroup.com.br/gestao-ia/"`
Expected: redirect controlado para o login ou HTTP `200` da tela de entrada, nunca `404`/`502`.

Run: `curl.exe -I "https://ia.solutiongroup.com.br/gestao-ia/api/health"`
Expected: HTTP `200`.

- [ ] **Step 3: Validar o início do OAuth**

Abrir `/gestao-ia/login`, iniciar Microsoft 365 e verificar que `redirect_uri` continua exatamente `https://ia.solutiongroup.com.br/login`, com `state` assinado iniciado por `gestao-ia.`.

- [ ] **Step 4: Manter o callback aguardando a ponte**

Até a Task 5, não concluir a autenticação de produção. Confirmar que nenhum redirect URI novo foi adicionado no Azure e que Orçamentos/Documental continuam autenticando normalmente.

- [ ] **Step 5: Registrar os resultados**

Adicionar status HTTP, destinos e timestamp à evidência, sem salvar query OAuth.

### Task 5: Estender a ponte `/login` do portal

**Files (repo `solutiongroup-ia-portal`):**
- Modify: `nginx.conf`
- Modify: `tests/portal.test.ps1`
- Modify: `tests/login-bridge.integration.ps1`
- Modify: `README.md`

**Interfaces:**
- Produces: state `gestao-ia.*` -> `/gestao-ia/api/auth/microsoft/callback`.
- Preserva: fallbacks existentes de Orçamentos e Documental.

- [ ] **Step 1: Escrever os testes falhos da nova ponte**

Adicionar ao teste de integração:

```powershell
$query = "?code=admin-code&state=gestao-ia.XYz%2F-_&session_state=abc"
$response = $client.GetAsync("/login$query").GetAwaiter().GetResult()
Assert-Equal (Get-PathAndQuery $response.Headers.Location) "/gestao-ia/api/auth/microsoft/callback$query" "Gestao IA callback must preserve the original query"
```

Manter os testes de callback sem state, sem code/error, query codificada, `no-store`, `no-referrer` e ausência de logs.

- [ ] **Step 2: Executar e confirmar a falha**

Run: `powershell -ExecutionPolicy Bypass -File tests/portal.test.ps1`
Expected: FAIL porque `nginx.conf` ainda não contém o callback da gestão.

- [ ] **Step 3: Alterar somente o mapa de state**

Adicionar antes do fallback:

```nginx
~^gestao-ia\. /gestao-ia/api/auth/microsoft/callback;
```

Não alterar a validação de callback nem reconstruir a query.

- [ ] **Step 4: Executar testes estáticos e Docker**

Run: `powershell -ExecutionPolicy Bypass -File tests/portal.test.ps1`
Expected: `Portal static checks passed`.

Run: `powershell -ExecutionPolicy Bypass -File tests/login-bridge.integration.ps1`
Expected: `Login bridge integration checks passed`.

- [ ] **Step 5: Commit, push e deploy do portal**

```bash
git add nginx.conf tests/portal.test.ps1 tests/login-bridge.integration.ps1 README.md
git commit -m "feat: route ai cost management login"
git push origin main
```

No EasyPanel, implantar somente `solutiongroup-ia` pelo commit novo. Não alterar porta, domínio ou outros serviços.

### Task 6: Validar autenticação e perfis em produção

**Files (repo central):**
- Modify: `docs/EASYPANEL_PUBLICATION_EVIDENCE.json`

**Interfaces:**
- Produces: evidência `anonymous`, `unprovisioned`, `viewer` e `admin`.

- [ ] **Step 1: Testar navegador sem cache**

Abrir uma janela InPrivate em `/gestao-ia/`, entrar com Microsoft e confirmar que o endereço final permanece sob `https://ia.solutiongroup.com.br/gestao-ia/`.

- [ ] **Step 2: Testar os quatro estados**

Anônimo deve ir ao login; conta não provisionada deve ver acesso negado; `viewer` deve consultar e não alterar; `admin` deve consultar e alterar um limite de homologação com auditoria.

- [ ] **Step 3: Verificar segurança do callback**

Confirmar que parâmetros `code`, `state`, `error_description` e cookies não aparecem nos logs Nginx, Next.js ou EasyPanel.

- [ ] **Step 4: Executar Playwright contra produção**

Run: `BASE_URL=https://ia.solutiongroup.com.br pnpm verify:production`
Expected: health, base path, redirects e assets passam; testes mutáveis usam apenas fixtures marcados `metadata.test=true`.

- [ ] **Step 5: Registrar evidência sanitizada**

Salvar apenas status, perfil, horário e resultado, sem tokens, cookies ou query OAuth.

### Task 7: Adicionar o card ao portal raiz

**Files (repo `solutiongroup-ia-portal`):**
- Modify: `index.html`
- Modify: `styles.css`
- Modify: `tests/portal.test.ps1`
- Modify: `README.md`

**Interfaces:**
- Produces: card `Acessar gestão de custos de IA` -> `/gestao-ia/`.

- [ ] **Step 1: Escrever o teste falho do card**

```powershell
Assert-Contains $html 'href="/gestao-ia/"' "Missing AI cost management link"
Assert-Contains $html "Acessar gestão de custos de IA" "Missing AI cost management label"
Assert-Contains $styles '.module-link[href="/gestao-ia/"]' "Missing AI cost management accent"
```

- [ ] **Step 2: Executar e confirmar a falha**

Run: `powershell -ExecutionPolicy Bypass -File tests/portal.test.ps1`
Expected: FAIL por link ausente.

- [ ] **Step 3: Adicionar card e cor própria**

Adicionar o link depois do Documental, com faixa lateral `#6d5aa7`, foco visível e o mesmo ícone de navegação dos demais cards. Não alterar destinos, cores ou textos dos cards atuais.

- [ ] **Step 4: Validar portal**

Run: `powershell -ExecutionPolicy Bypass -File tests/portal.test.ps1`
Expected: `Portal static checks passed`.

Run: `powershell -ExecutionPolicy Bypass -File tests/login-bridge.integration.ps1`
Expected: `Login bridge integration checks passed`.

- [ ] **Step 5: Commit, push e publicação**

```bash
git add index.html styles.css tests/portal.test.ps1 README.md
git commit -m "feat: add ai cost management portal entry"
git push origin main
```

Implantar somente `solutiongroup-ia` e confirmar o card em janela sem cache.

### Task 8: Importar, reconciliar e ativar gradualmente

**Files (repo central):**
- Modify: `docs/EASYPANEL_PUBLICATION_EVIDENCE.json`
- Modify: `docs/AI_COST_CONTROL_ROLLOUT.md`

**Interfaces:**
- Produces: central em estado `enforcing` somente após todos os gates.

- [ ] **Step 1: Importar históricos**

Run: `pnpm import:orcamentos && pnpm import:documental`
Expected: imports concluídos, duplicatas `0` na primeira execução e todos os registros duplicados/ignorados na segunda.

- [ ] **Step 2: Ativar gravação dupla em `report_only`**

Implantar os adaptadores nos serviços Orçamentos, Documental web e Documental worker sem ativar bloqueio. Executar chamadas controladas de cada feature e verificar evento local e central com o mesmo `source_event_id`.

- [ ] **Step 3: Reconciliar antes dos alertas**

Run: `pnpm reconcile:usage -- --from-evidence=docs/EASYPANEL_PUBLICATION_EVIDENCE.json`
Expected: chamadas, tokens e USD iguais; diferenças apenas classificadas e justificadas.

- [ ] **Step 4: Ativar `alerting` e depois `enforcing`**

Criar limites de homologação, testar e-mail e painel, então ativar bloqueio no Orçamentador. Após sucesso, ativar Documental web e por último Documental worker. Em cada etapa, provar permissão abaixo do limite, bloqueio acima, exceção temporária e retorno ao normal.

- [ ] **Step 5: Fechar evidência e rollback**

Registrar commits, horários, modos e resultados. O rollback consiste em retornar a integração para `report_only`; não remover eventos, migrations ou outbox e não reverter outros serviços.

### Task 9: Verificação final do domínio e dos serviços preservados

**Files (repo central):**
- Create: `docs/PRODUCTION_ACCEPTANCE_2026-08-01.md`

**Interfaces:**
- Produces: aceite ponta a ponta e lista de riscos residuais.

- [ ] **Step 1: Verificar URLs sem cache**

Confirmar exatamente:

- `https://ia.solutiongroup.com.br/`
- `https://ia.solutiongroup.com.br/gestao-ia/`
- `https://ia.solutiongroup.com.br/orcamentos/`
- `https://ia.solutiongroup.com.br/documental`
- `https://ia.solutiongroup.com.br/relatorios/`
- `https://ia.solutiongroup.com.br/erosao`

- [ ] **Step 2: Verificar card e destino final**

Em InPrivate, clicar `Acessar gestão de custos de IA` e confirmar que a navegação termina exatamente em `https://ia.solutiongroup.com.br/gestao-ia/` após autenticação.

- [ ] **Step 3: Verificar desktop e mobile**

Capturar Playwright em `1440x900` e `390x844`; confirmar conteúdo não vazio, sem sobreposição, sem texto cortado e sem rolagem horizontal global.

- [ ] **Step 4: Verificar isolamento operacional**

No EasyPanel, confirmar os serviços existentes verdes e sem mudança de domínio/porta. Comparar configurações antes/depois e registrar somente diferenças esperadas: novo serviço, nova rota, adaptadores e novo card.

- [ ] **Step 5: Commit do aceite**

```bash
git add docs/PRODUCTION_ACCEPTANCE_2026-08-01.md docs/EASYPANEL_PUBLICATION_EVIDENCE.json
git commit -m "docs: record central ai cost production acceptance"
git push origin main
```
