# Solution Group IA Portal

Portal raiz estático publicado em `https://ia.solutiongroup.com.br/`.

## Conteudo

- `index.html`: home de navegação do portal raiz.
- `styles.css`: estilos do mini site.
- `assets/solutiongroup-ia-mark.svg`: marca visual local usada pela home.
- `nginx.conf`: configuração Nginx para servir o site na porta 80.
- `Dockerfile`: imagem Nginx para deploy pelo EasyPanel.

## Execução local

```powershell
docker build -t solutiongroup-ia-portal .
docker run --rm -p 8080:80 solutiongroup-ia-portal
```

Depois acesse `http://localhost:8080/`.

## Ponte central de login

O Nginx atende a rota exata `/login` sem registrar a query do callback. Estados com
prefixo `documental.` seguem para o callback do Copiloto Documental; os demais
callbacks OAuth válidos continuam em `/orcamentos/login`.

A rota exata `/login` no EasyPanel deve continuar no `solutiongroup-orcamentos` até
esta versão do portal ser publicada e validada. Em caso de falha em qualquer login,
ela deve ser devolvida imediatamente ao Orçamentador.

## Deploy

Conectar somente o serviço EasyPanel `solutiongroup-ia` a este repositório Git usando:

- Build: `Dockerfile`
- Porta interna: `80`
- Domínio: manter `https://ia.solutiongroup.com.br/`

Não alterar os serviços `solutiongroup-orcamentos`, `solutiongroup-relatorios` ou `solutiongroup-documental`.
