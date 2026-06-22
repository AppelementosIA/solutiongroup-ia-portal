# Solution Group IA Portal

Portal raiz estatico publicado em `https://ia.solutiongroup.com.br/`.

## Conteudo

- `index.html`: home de navegacao do portal raiz.
- `styles.css`: estilos do mini site.
- `assets/solutiongroup-ia-mark.svg`: marca visual local usada pela home.
- `nginx.conf`: configuracao Nginx para servir o site na porta 80.
- `Dockerfile`: imagem Nginx para deploy pelo EasyPanel.

## Execucao local

```powershell
docker build -t solutiongroup-ia-portal .
docker run --rm -p 8080:80 solutiongroup-ia-portal
```

Depois acesse `http://localhost:8080/`.

## Deploy

Conectar somente o servico EasyPanel `solutiongroup-ia` a este repositorio Git usando:

- Build: `Dockerfile`
- Porta interna: `80`
- Dominio: manter `https://ia.solutiongroup.com.br/`

Nao alterar os servicos `solutiongroup-orcamentos`, `solutiongroup-relatorios` ou `solutiongroup-documental`.
