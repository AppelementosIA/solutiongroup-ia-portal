$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$indexPath = Join-Path $root "index.html"
$stylesPath = Join-Path $root "styles.css"
$dockerfilePath = Join-Path $root "Dockerfile"
$nginxPath = Join-Path $root "nginx.conf"

function Assert-Contains {
    param(
        [string]$Content,
        [string]$Expected,
        [string]$Message
    )

    if (-not $Content.Contains($Expected)) {
        throw $Message
    }
}

function Assert-NotContains {
    param(
        [string]$Content,
        [string]$Unexpected,
        [string]$Message
    )

    if ($Content.Contains($Unexpected)) {
        throw $Message
    }
}

if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "index.html not found"
}

if (-not (Test-Path -LiteralPath $stylesPath)) {
    throw "styles.css not found"
}

if (-not (Test-Path -LiteralPath $dockerfilePath)) {
    throw "Dockerfile not found"
}

if (-not (Test-Path -LiteralPath $nginxPath)) {
    throw "nginx.conf not found"
}

$html = Get-Content -LiteralPath $indexPath -Raw
$styles = Get-Content -LiteralPath $stylesPath -Raw
$dockerfile = Get-Content -LiteralPath $dockerfilePath -Raw
$nginx = Get-Content -LiteralPath $nginxPath -Raw

Assert-Contains $html "<h1>Solution Group IA</h1>" "Missing required portal title"
Assert-Contains $html "Portal de implantação de inteligência artificial em preparação." "Missing required portal message"
Assert-Contains $html "href=`"/orcamentos/`"" "Missing orcamentos link"
Assert-Contains $html "Acessar módulo de orçamentos" "Missing orcamentos link label"
Assert-Contains $html "href=`"/relatorios/`"" "Missing relatorios link"
Assert-Contains $html "href=`"/documental`"" "Missing Documental link"
Assert-Contains $html '<a class="module-link" href="/documental">' "Documental link must be visible in the portal"
Assert-NotContains $html 'href="/documental" hidden' "Documental link must not be hidden"
Assert-Contains $html "Acessar Copiloto Documental" "Missing Documental link label"
Assert-Contains $html "Acessar módulo de relatórios" "Missing relatorios link label"
Assert-Contains $html 'href="https://ia.solutiongroup.com.br/erosao"' "Erosao link must use the production portal URL"
Assert-Contains $html "Acessar APP de relatório de erosão" "Missing erosao link label"
Assert-Contains $html 'href="/gestao-ia"' "Missing central AI cost management link"
Assert-Contains $html "Acessar gestão central de custos de IA" "Missing central AI cost management label"
Assert-NotContains $html "vercel.app" "Portal must not link to Vercel"

Assert-Contains $styles "--module-accent: var(--accent);" "Orcamentos card must use the institutional accent color"
Assert-Contains $styles ".module-link[href=`"/relatorios/`"] {`n  --module-accent: #d14343;`n}" "Relatorios card must use a red accent color"
Assert-Contains $styles ".module-link[href=`"/documental`"] {`n  --module-accent: #2563a6;`n}" "Documental card must use a blue accent color"
Assert-Contains $styles ".module-link[href=`"https://ia.solutiongroup.com.br/erosao`"] {`n  --module-accent: #d18b17;`n}" "Erosao report card must use a yellow accent color"
Assert-Contains $styles ".module-link[href=`"/gestao-ia`"] {`n  --module-accent: #6f42c1;`n}" "Central AI cost card must use its own accent color"
Assert-Contains $styles "border-left: 4px solid var(--module-accent);" "Module cards must use their own accent color"
Assert-Contains $styles "border-color: var(--module-accent);" "Module hover and focus must use the card accent color"
Assert-Contains $styles ".module-link[hidden] {`n  display: none;`n}" "Hidden module cards must override the flex layout"

Assert-Contains $dockerfile "FROM nginx:" "Dockerfile must use Nginx"
Assert-Contains $dockerfile "EXPOSE 80" "Dockerfile must expose port 80"
Assert-Contains $dockerfile "nginx.conf" "Dockerfile must copy nginx.conf"

Assert-Contains $nginx "listen 80;" "Nginx must listen on port 80"
Assert-Contains $nginx "absolute_redirect off;" "OAuth redirects must stay relative behind the EasyPanel HTTPS proxy"
Assert-Contains $nginx "root /usr/share/nginx/html;" "Nginx root must point to static html directory"
Assert-Contains $nginx "location = /login" "Nginx must serve the exact central login bridge route"
Assert-Contains $nginx "/documental/api/auth/microsoft/callback" "Login bridge must route Documental callbacks"
Assert-Contains $nginx "/gestao-ia/api/auth/microsoft/callback" "Login bridge must route central AI cost callbacks"
Assert-Contains $nginx "/orcamentos/login" "Login bridge must preserve the Orcamentador fallback"
Assert-Contains $nginx 'Cache-Control "no-store" always;' "Login bridge must disable caching"
Assert-Contains $nginx 'Referrer-Policy "no-referrer" always;' "Login bridge must suppress referrer data"
Assert-Contains $nginx "access_log off;" "Login bridge must not log callback queries"
Assert-Contains $nginx '$is_args$args' "Login bridge must forward the original query without rebuilding it"

Write-Output "Portal static checks passed"
