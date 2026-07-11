# Cores dos cards de módulos

## Objetivo

Diferenciar visualmente os três módulos do portal raiz sem alterar seus textos,
rotas ou os demais serviços da plataforma.

## Decisao visual

Cada card mantém uma listra lateral de 4 px e usa a mesma cor no estado de
hover e foco:

- Orçamentos (`/orcamentos/`): verde institucional `#168c7f`.
- Relatórios (`/relatorios/`): vermelho `#d14343`.
- APP de relatório de erosão (`/erosao/`): amarelo `#d18b17`.

Os cards continuam com fundo branco, texto escuro e borda arredondada. A cor
serve apenas como indicador lateral e como cor de destaque ao interagir.

## Implementacao

O CSS define uma variável de cor por card. A regra comum usa essa variável para
a listra lateral, e as regras de hover e foco a reutilizam para manter o
indicador visivel e coerente.

## Fora de escopo

Não alterar domínio, DNS, login Microsoft, rotas, conteúdo dos cards ou os
serviços `solutiongroup-orcamentos`, `solutiongroup-relatorios` e
`solutiongroup-documental`.

## Verificacao

O teste estático deve validar a cor configurada para cada um dos três cards.
Depois da publicação, a página raiz deve exibir as listras verde, vermelha e
amarela nessa ordem.
