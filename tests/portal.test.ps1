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
Assert-Contains $html "Acessar módulo de relatórios" "Missing relatorios link label"
Assert-Contains $html "href=`"/erosao/`"" "Missing erosao link"
Assert-Contains $html "Acessar APP de relatório de erosão" "Missing erosao link label"

Assert-Contains $styles "--module-accent: var(--accent);" "Orcamentos card must use the institutional accent color"
Assert-Contains $styles ".module-link:nth-child(2) {`n  --module-accent: #d14343;`n}" "Relatorios card must use a red accent color"
Assert-Contains $styles ".module-link:last-child {`n  --module-accent: #d18b17;`n}" "Erosao report card must use a yellow accent color"
Assert-Contains $styles "border-left: 4px solid var(--module-accent);" "Module cards must use their own accent color"
Assert-Contains $styles "border-color: var(--module-accent);" "Module hover and focus must use the card accent color"

Assert-Contains $dockerfile "FROM nginx:" "Dockerfile must use Nginx"
Assert-Contains $dockerfile "EXPOSE 80" "Dockerfile must expose port 80"
Assert-Contains $dockerfile "nginx.conf" "Dockerfile must copy nginx.conf"

Assert-Contains $nginx "listen 80;" "Nginx must listen on port 80"
Assert-Contains $nginx "root /usr/share/nginx/html;" "Nginx root must point to static html directory"

Write-Output "Portal static checks passed"
