# Plataforma central de gestão de custos de IA

## Objetivo

Criar uma plataforma administrativa independente para consolidar, acompanhar e controlar os gastos de inteligência artificial de todos os módulos da Solution Group.

A solução reaproveitará o ledger, o cálculo de custos, os filtros e os painéis já implementados no Orçamentador (Elementus Etapa 2) e no Copiloto Documental (Elementus Etapa 3). A nova plataforma será a autoridade central para limites, alertas e bloqueios, sem armazenar prompts, respostas ou conteúdo documental.

## Decisões aprovadas

- Novo repositório: `AppelementosIA/solutiongroup-ia-gestao`.
- Novo serviço no EasyPanel: `solutiongroup-gestao-ia`.
- URL pública: `https://ia.solutiongroup.com.br/gestao-ia/`.
- Arquitetura central com API própria, em vez de acesso direto dos módulos ao banco.
- Limite mensal de alerta e limite mensal de bloqueio.
- Políticas globais e específicas por módulo, usuário e modelo.
- Prevalece sempre o limite aplicável mais restritivo.
- Login Microsoft 365 e acesso administrativo por perfil.
- Integração gradual, com monitoramento, gravação dupla, alertas e somente depois bloqueio.
- Nenhum domínio, DNS ou serviço existente será substituído.

## Base existente reutilizada

### Orçamentador, Elementus Etapa 2

O Orçamentador já possui:

- tabela imutável `orc_ai_usage_events`;
- registrador tolerante a falhas;
- extração de tokens da OpenAI Responses API;
- contabilização de pesquisas web;
- cálculo de custo estimado por modelo;
- snapshot da tarifa utilizada;
- contexto de proposta, item e usuário;
- endpoint administrativo com filtros e paginação;
- painel com totais, evolução diária, usuário, funcionalidade, modelo e eventos;
- autorização administrativa server-side.

### Copiloto Documental, Elementus Etapa 3

O Documental amplia esse contrato com:

- tabela `ai_usage_events`;
- eventos originados no servidor web e no worker;
- atores humanos e automáticos;
- chat, embeddings, classificação, OCR e rerank;
- tokens, quantidade de requisições e unidades faturáveis;
- contexto de conversa, documento, edital e job de ingestão;
- registradores equivalentes em JavaScript e Python;
- painel administrativo no padrão visual atual da Solution Group.

O esquema central partirá do contrato mais abrangente do Documental e incorporará os vínculos comerciais do Orçamentador.

## Arquitetura

### Aplicação

A plataforma será uma aplicação Next.js com App Router, API Node.js e banco PostgreSQL/Supabase. Essa escolha permite reaproveitar diretamente o painel do Documental e manter interface, autenticação e API no mesmo serviço.

O serviço será empacotado em Docker e publicado no EasyPanel. Ele deverá respeitar o prefixo `/gestao-ia/` em páginas, assets, APIs e redirecionamentos.

### Separação de responsabilidades

- Os módulos continuam responsáveis por executar suas operações de IA e extrair as métricas entregues pelos provedores.
- A plataforma central recebe eventos normalizados, calcula ou valida os custos, aplica limites e produz os painéis.
- O navegador nunca recebe credenciais de serviço nem consulta o banco diretamente.
- Cada módulo possui uma credencial interna própria, revogável e limitada ao seu identificador de serviço.
- A API central é a única autoridade para permitir ou bloquear uma nova chamada paga.

### Fluxo de uma chamada paga

1. O módulo identifica usuário, funcionalidade, provedor, modelo e contexto de negócio.
2. O módulo solicita uma reserva de custo à API central.
3. A API calcula a política efetiva e realiza, em transação, a reserva no orçamento mensal.
4. Se algum limite de bloqueio for atingido, a reserva é recusada e o provedor não é chamado.
5. Se autorizada, a operação de IA é executada normalmente.
6. O módulo envia as métricas reais de uso para liquidar a reserva.
7. A plataforma substitui o valor reservado pelo custo estimado apurado e grava um evento imutável.
8. Se o limite de alerta for atingido, a plataforma cria a notificação uma única vez para aquela política e período.

### Indisponibilidade central

O controle será `fail-open`: uma falha temporária da plataforma central não poderá derrubar Orçamentos ou Documental.

Nessa situação:

- o módulo continua a operação;
- o ledger local permanece sendo gravado;
- o adaptador registra a pendência em uma outbox local;
- a pendência é reenviada de forma idempotente quando a integração voltar;
- a tela de integrações mostra o atraso e a última sincronização bem-sucedida.

Esse comportamento preserva a operação, mas pode permitir pequeno consumo acima do limite durante uma indisponibilidade. A ocorrência ficará visível na auditoria operacional.

## Modelo de dados central

### `ai_usage_events`

Uma linha imutável por tentativa lógica de uso de IA:

- identidade: `id`, `occurred_at`, `period_key`, `service`, `source`, `feature`;
- idempotência: `source_event_id`, `idempotency_key`;
- provedor: `provider`, `model`, `provider_request_id`;
- ator: `actor_type`, `user_id`, `user_email`, `user_name`;
- contexto genérico: `context_type`, `context_id`, `context_label`;
- contexto conhecido: proposta, item, conversa, documento, edital e job de ingestão;
- resultado: `status`, `latency_ms`, `error_code`, mensagem técnica sanitizada;
- consumo: tokens de entrada, saída e total, quantidade de requisições, unidades faturáveis e sua unidade;
- custo: `estimated_cost_usd`, `exchange_rate_brl`, `estimated_cost_brl`;
- rastreabilidade: `pricing_snapshot`, `exchange_rate_snapshot`, `metadata` sanitizado;
- integração: `reservation_id`, `received_at`, `reconciled_at`.

Uma restrição única em `service + source_event_id` impede duplicidade durante importação, gravação dupla ou reenvio da outbox.

### `ai_budget_policies`

Políticas mensais com:

- escopo `global`, `service`, `user` ou `model`;
- identificador do escopo;
- valor de alerta em reais;
- valor de bloqueio em reais;
- estado ativo ou suspenso;
- vigência inicial e final;
- responsável e justificativa da última alteração.

O limite de alerta deve ser menor que o limite de bloqueio. Para uma chamada, todas as políticas aplicáveis são avaliadas e qualquer uma delas pode impedir a reserva. E-mails de usuário serão normalizados antes da comparação.

### `ai_usage_reservations`

Reservas de custo com estados `active`, `settled`, `cancelled` e `expired`. Cada reserva possui valor, expiração curta, módulo, usuário, modelo e chave de idempotência.

Reservas expiradas são liberadas automaticamente. Quando as métricas do provedor não permitirem apurar o custo estimado, a plataforma mantém um valor conservador configurado até a reconciliação.

A decisão considera, em uma única transação, eventos liquidados e reservas ativas do período. Uma mesma reserva compromete o saldo de todas as políticas aplicáveis, mas seu valor aparece apenas uma vez nos totais gerais.

O bloqueio não será habilitado para um modelo enquanto ele não possuir tarifa ou custo máximo de reserva configurado.

### Tabelas administrativas

- `ai_provider_prices`: tarifas por provedor, modelo, unidade e vigência.
- `ai_exchange_rates`: cotação USD/BRL e origem administrativa.
- `ai_alerts`: alertas emitidos e estado de leitura/envio.
- `ai_integrations`: módulos, credenciais, permissões e último contato.
- `ai_admin_users`: e-mail, perfil e situação do acesso.
- `ai_budget_exceptions`: liberações temporárias com valor, validade e justificativa.
- `ai_audit_log`: histórico imutável de alterações administrativas.

Todas as tabelas terão RLS habilitada. Clientes autenticados não terão acesso direto; leituras e escritas passarão pelo servidor.

## Custos, câmbio e limites

- O uso original e o custo estimado em dólares serão preservados.
- Os limites administrativos serão definidos em reais.
- Cada evento guardará a cotação utilizada, evitando alteração retroativa do histórico.
- A primeira versão permitirá cotação administrada manualmente, com vigência e auditoria.
- O painel sempre utilizará a expressão `Custo estimado`.
- Chamadas sem uso ou tarifa serão registradas como `Não calculado` e destacadas para correção.
- O valor oficial continuará sendo a fatura do provedor; a plataforma não alegará conciliação contábil automática.
- Os períodos mensais serão calculados em `America/Sao_Paulo`.
- Eventos históricos anteriores à vigência das políticas serão exibidos, mas não consumirão retroativamente limites criados depois deles.

## Alertas, bloqueios e exceções

Cada política possui exatamente dois marcos:

- **Alerta:** informa que o consumo atingiu o valor configurado, sem interromper chamadas.
- **Bloqueio:** impede novas chamadas pagas que se enquadrem naquela política.

O alerta aparecerá no painel e será enviado por e-mail aos administradores. O sistema evitará mensagens repetidas para a mesma política no mesmo mês.

Quando houver bloqueio, o módulo mostrará uma mensagem natural, por exemplo:

> O limite mensal de consumo de IA foi atingido. Procure o administrador da plataforma para solicitar uma liberação.

Um administrador poderá:

- aumentar os limites;
- suspender temporariamente uma política;
- criar uma exceção com valor e validade;
- encerrar uma exceção antes do prazo.

Toda ação exige justificativa e gera registro de auditoria.

## API interna

Endpoints previstos para módulos:

- `POST /api/internal/v1/reservations`: valida políticas e reserva custo.
- `POST /api/internal/v1/reservations/{id}/settle`: liquida a reserva com uso e custo reais.
- `POST /api/internal/v1/reservations/{id}/cancel`: cancela uma reserva não utilizada.
- `POST /api/internal/v1/events`: recebe evento idempotente para importação, outbox ou operações sem reserva.
- `POST /api/internal/v1/integrations/heartbeat`: informa saúde e versão do adaptador.

Cada requisição será autenticada por credencial de integração e identificador do módulo. As credenciais serão armazenadas de forma segura, poderão ser rotacionadas e não serão compartilhadas entre serviços. O servidor validará esquema, escopo, tamanho, idempotência e campos proibidos.

As rotas acima são caminhos lógicos da aplicação; externamente permanecerão sob o prefixo público `/gestao-ia/`.

## API administrativa

Endpoints autenticados fornecerão:

- resumo e série diária;
- agrupamentos por módulo, usuário, funcionalidade, provedor e modelo;
- eventos paginados e exportação CSV;
- consulta e manutenção de políticas;
- preços e câmbio;
- alertas e exceções;
- integrações e sincronização;
- auditoria.

A API será a autoridade de autorização. Ocultar um item na interface não substituirá a validação server-side.

## Interface

A interface será uma ferramenta administrativa compacta e orientada à leitura frequente, com navegação lateral e as seguintes áreas.

### Visão geral

- gasto estimado do mês em reais e dólares;
- percentual do alerta e do bloqueio;
- saldo disponível;
- projeção até o fim do mês;
- chamadas, tokens, erros e itens sem preço;
- módulos em alerta ou bloqueados;
- evolução diária do custo.

### Consumo

- filtros por período, módulo, usuário, funcionalidade, provedor, modelo e status;
- distribuição por módulo, usuário, funcionalidade e modelo;
- comparação com o mês anterior;
- identificação visual de consumo humano e automático.

### Eventos

Tabela paginada com data, módulo, usuário ou sistema, contexto, funcionalidade, modelo, tokens, unidades faturáveis, duração, resultado e custo estimado.

### Limites

Configuração das políticas globais e por módulo, usuário e modelo, com visualização clara do limite efetivo e do consumo corrente.

### Preços e câmbio

Cadastro versionado de tarifas e cotação, incluindo vigência, fonte informada e modelos ainda sem precificação.

### Integrações

Situação de cada módulo, última comunicação, último evento, quantidade de pendências e resultado da última reconciliação.

### Auditoria

Histórico de alterações de limites, preços, câmbio, usuários, bloqueios e exceções.

## Autenticação e autorização

O acesso usará Microsoft 365, aproveitando a ponte central de login existente no portal. O `returnTo` deverá aceitar somente destinos internos permitidos, incluindo `/gestao-ia/`.

Perfis:

- `admin`: consulta dados e altera limites, preços, câmbio, integrações, usuários e exceções;
- `viewer`: consulta painéis e exporta relatórios, sem realizar alterações.

Usuários não autenticados serão redirecionados ao login. Usuários autenticados sem provisionamento verão acesso negado. Falha ou ausência de configuração resultará em acesso negado por padrão.

## Portal raiz

Depois que a plataforma estiver publicada e validada, o portal raiz receberá um card `Gestão de custos de IA`, apontando exclusivamente para `/gestao-ia/`.

Os cards atuais e seus destinos não serão alterados. O domínio raiz continuará sendo `https://ia.solutiongroup.com.br/`.

## Migração e implantação gradual

### Fase 1: plataforma em modo informativo

- criar repositório, banco, API, interface e serviço EasyPanel;
- cadastrar preços, câmbio, usuários e integrações;
- manter bloqueio desligado.

### Fase 2: importação histórica

- importar `orc_ai_usage_events` da Etapa 2;
- importar `ai_usage_events` da Etapa 3;
- preservar IDs de origem, timestamps, snapshots e custos existentes;
- não inventar valores ausentes;
- validar totais por dia, módulo e modelo.

### Fase 3: gravação dupla

- adicionar adaptadores pequenos ao Orçamentador e Documental;
- manter os ledgers locais;
- enviar novos eventos também para a central;
- reconciliar diferenças e testar a outbox.

### Fase 4: alertas

- ativar políticas sem bloqueio;
- validar alertas no painel e por e-mail;
- acompanhar pelo menos um ciclo controlado de chamadas.

### Fase 5: bloqueio gradual

- habilitar primeiro em um módulo;
- testar concorrência, exceção e indisponibilidade central;
- habilitar no segundo módulo após validação;
- tornar o ledger central a fonte administrativa oficial.

## Testes e critérios de aceite

- Imports são idempotentes e mantêm os totais das fontes.
- Eventos repetidos não duplicam custo.
- O custo usa a tarifa e a cotação vigentes, preservadas em snapshot.
- Uma reserva concorrente não permite ultrapassar silenciosamente o limite disponível.
- Alerta não bloqueia chamadas.
- Bloqueio impede a chamada antes de acessar o provedor.
- Políticas globais, de módulo, usuário e modelo são combinadas corretamente.
- A política mais restritiva prevalece.
- Exceções temporárias expiram automaticamente.
- Reservas abandonadas expiram e liberam saldo.
- Falha de telemetria não derruba a operação principal.
- Pendências da outbox são reenviadas sem duplicação.
- Prompts, respostas, documentos, chaves e tokens de acesso são rejeitados ou removidos.
- Administradores podem alterar configurações; visualizadores não podem.
- Usuários sem provisionamento não acessam páginas nem APIs.
- Interface funciona em desktop e mobile sem sobreposição ou rolagem global indevida.
- O serviço funciona integralmente sob `/gestao-ia/`.
- O card do portal termina exatamente em `https://ia.solutiongroup.com.br/gestao-ia/`.

## Fora do escopo inicial

- cobrança ou rateio contábil automático para clientes;
- conciliação automática com faturas oficiais dos provedores;
- substituição dos painéis oficiais de cobrança;
- alteração dos provedores ou modelos utilizados pelos módulos;
- reconstrução estimada de histórico sem métricas confiáveis;
- bloqueio de funcionalidades que não utilizam IA paga;
- mudanças de DNS, domínio raiz ou serviços não relacionados.
