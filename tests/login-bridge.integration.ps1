$ErrorActionPreference = "Stop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Warning "Docker is not available; login bridge integration checks were skipped"
    exit 0
}

Add-Type -AssemblyName System.Net.Http

$root = Split-Path -Parent $PSScriptRoot
$suffix = "$PID-$(Get-Random -Minimum 1000 -Maximum 9999)"
$imageName = "solutiongroup-ia-portal-test:$suffix"
$containerName = "solutiongroup-ia-portal-test-$suffix"
$port = Get-Random -Minimum 18080 -Maximum 18999
$imageBuilt = $false
$containerStarted = $false
$handler = $null
$client = $null

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected', received '$Actual'."
    }
}

function Get-PathAndQuery {
    param([System.Uri]$Location)

    if ($Location.IsAbsoluteUri) {
        return $Location.PathAndQuery
    }

    return $Location.OriginalString
}

try {
    docker build --quiet --tag $imageName $root | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker image build failed"
    }
    $imageBuilt = $true

    docker run --detach --rm --name $containerName --publish "${port}:80" $imageName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker container start failed"
    }
    $containerStarted = $true

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.BaseAddress = [System.Uri]::new("http://127.0.0.1:$port")

    $ready = $false
    foreach ($attempt in 1..20) {
        try {
            $probe = $client.GetAsync("/").GetAwaiter().GetResult()
            if ($probe.IsSuccessStatusCode) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }
    if (-not $ready) {
        throw "Nginx test container did not become ready"
    }

    $documentalQuery = "?code=abc%2B123&state=documental.XYz%2F-_&session_state=same%2Fthing"
    $documental = $client.GetAsync("/login$documentalQuery").GetAwaiter().GetResult()
    Assert-Equal ([int]$documental.StatusCode) 302 "Documental callback must redirect"
    Assert-Equal (Get-PathAndQuery $documental.Headers.Location) "/documental/api/auth/microsoft/callback$documentalQuery" "Documental callback must preserve the original query"

    $orcamentosQuery = "?code=budget-code&state=orcamentos.123&scope=openid%20profile"
    $orcamentos = $client.GetAsync("/login$orcamentosQuery").GetAwaiter().GetResult()
    Assert-Equal ([int]$orcamentos.StatusCode) 302 "Orcamentador callback must redirect"
    Assert-Equal (Get-PathAndQuery $orcamentos.Headers.Location) "/orcamentos/login$orcamentosQuery" "Orcamentador callback must preserve the original query"

    $errorQuery = "?error=access_denied&error_description=Denied%20by%20user&state=documental.error-state"
    $oauthError = $client.GetAsync("/login$errorQuery").GetAwaiter().GetResult()
    Assert-Equal ([int]$oauthError.StatusCode) 302 "OAuth errors must redirect"
    Assert-Equal (Get-PathAndQuery $oauthError.Headers.Location) "/documental/api/auth/microsoft/callback$errorQuery" "OAuth errors must preserve the original query"

    $missingCallback = $client.GetAsync("/login?state=documental.no-callback").GetAwaiter().GetResult()
    Assert-Equal (Get-PathAndQuery $missingCallback.Headers.Location) "/" "Requests without an OAuth callback must return to the portal"

    $missingState = $client.GetAsync("/login?code=orphan-code").GetAwaiter().GetResult()
    Assert-Equal (Get-PathAndQuery $missingState.Headers.Location) "/" "Requests without state must return to the portal"

    Assert-Equal ($documental.Headers.CacheControl.NoStore) $true "Login bridge must set Cache-Control: no-store"
    Assert-Equal (($documental.Headers.GetValues("Referrer-Policy") -join ",")) "no-referrer" "Login bridge must set Referrer-Policy: no-referrer"

    $logs = docker logs $containerName 2>&1 | Out-String
    if (
        $logs.Contains("code=") -or
        $logs.Contains("state=") -or
        $logs.Contains("error_description=")
    ) {
        throw "Login bridge wrote callback parameters to container logs"
    }

    Write-Output "Login bridge integration checks passed"
}
finally {
    if ($client) {
        $client.Dispose()
    }
    if ($handler) {
        $handler.Dispose()
    }
    if ($containerStarted) {
        docker stop $containerName | Out-Null
    }
    if ($imageBuilt) {
        docker image remove $imageName 2>$null | Out-Null
    }
}
