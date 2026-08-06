# EduEdu Setup Script em PowerShell
# ----------------- Configuracao Inicial -----------------

# Caminho absoluto do projeto (pasta acima de /scripts)
$projectRoot = Join-Path $PSScriptRoot ".."
Push-Location $projectRoot

# Caminho do .env
$envPath = Join-Path $projectRoot ".env"

# O .env e carregado em Main, e nao aqui, porque uma atualizacao pode acrescentar chaves
# a ele durante a execucao - e o processo precisa reler o arquivo depois disso.

$ip = ""

$hasDocker=$false
$hasWinget=$false
$hasWsl=$false

# "install" (limpa) ou "update" - definido em Show-MainMenu
$installAction = "install"

# Definidos em Main, consumidos por Stop-CurrentContainers e Build-Images
$ipChanged = $true
$skipBuild = $false

# ----------------- Utilitarios -----------------

function Write-Color($Text, $Color="White") {
    Write-Host $Text -ForegroundColor $Color  
}

function Spinner-Run($ScriptBlock, $Message) {
    $chars = "/-\|"
    $jobDone = $false

    # Start script in background using a Runspace
    $ps = [powershell]::Create()
    $ps.AddScript($ScriptBlock) | Out-Null
    $asyncResult = $ps.BeginInvoke()

    while (-not $asyncResult.IsCompleted) {
        foreach ($c in $chars.ToCharArray()) {
            if ($asyncResult.IsCompleted) { break }
            Write-Host -NoNewline "`r[ $c ] $Message"
            Start-Sleep -Milliseconds 100
        }
    }

    $ps.EndInvoke($asyncResult)
    $ps.Dispose()

    Write-Host "`r[ OK ] $Message" -ForegroundColor Green
}

# ----------------- Etapas, cronometro e estimativa -----------------

# Boa parte da instalacao e silenciosa por natureza (chamadas de API, download do
# pacote, pull de imagens). Sem indicacao de progresso a tela fica parada por minutos e
# o usuario nao sabe se travou. Cada etapa se anuncia, informa quanto levou e, quando ha
# historico, quanto levou da ultima vez.
#
# Os tempos da execucao anterior ficam em .install-timing.json, na raiz da instalacao.
# E so um auxilio de interface: se o arquivo sumir ou vier corrompido, tudo continua
# funcionando sem estimativa.

$timingPath = Join-Path $projectRoot ".install-timing.json"

$script:runStart     = $null
$script:phaseName    = $null
$script:phaseStart   = $null
$script:phaseTimings = @{}
$script:baseline     = $null

function Format-Duration($Seconds) {
    $s = [int][math]::Round($Seconds)
    if ($s -lt 60) { return "${s}s" }
    return "{0}min {1:d2}s" -f [int]($s / 60), ($s % 60)
}

function Get-ElapsedTotal {
    if (-not $script:runStart) { return 0 }
    return ((Get-Date) - $script:runStart).TotalSeconds
}

function Load-Baseline {
    if (-not (Test-Path $timingPath)) { return }
    try {
        $dados = Get-Content $timingPath -Raw | ConvertFrom-Json
        $mapa = @{}
        foreach ($p in $dados.PSObject.Properties) { $mapa[$p.Name] = [double]$p.Value }
        if ($mapa.Count -gt 0) { $script:baseline = $mapa }
    } catch {
        # Historico ilegivel nao e motivo para interromper nada.
        $script:baseline = $null
    }
}

# Mescla com o que ja existe em vez de sobrescrever: nem toda execucao passa por todas as
# etapas - uma reexecucao simples nao verifica versao nem faz copia de seguranca -, entao
# sobrescrever apagaria o historico das etapas que nao rodaram desta vez.
function Save-Baseline {
    if ($script:phaseTimings.Count -eq 0) { return }
    try {
        $mapa = @{}
        if ($script:baseline) { foreach ($k in $script:baseline.Keys) { $mapa[$k] = $script:baseline[$k] } }
        foreach ($k in $script:phaseTimings.Keys) { $mapa[$k] = $script:phaseTimings[$k] }

        $json = $mapa | ConvertTo-Json
        [System.IO.File]::WriteAllText($timingPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

# EDUEDU_START_TICKS atravessa a reexecucao pos-atualizacao: sem isso o processo filho
# comecaria a contar do zero e informaria no fim um tempo menor que o real.
function Start-Run {
    if ($env:EDUEDU_START_TICKS) {
        try { $script:runStart = [datetime]::new([long]$env:EDUEDU_START_TICKS) } catch { }
    }
    if (-not $script:runStart) {
        $script:runStart = Get-Date
        $env:EDUEDU_START_TICKS = $script:runStart.Ticks
    }

    Load-Baseline
}

function Start-Phase($Name) {
    $script:phaseName  = $Name
    $script:phaseStart = Get-Date

    $decorrido = Format-Duration (Get-ElapsedTotal)
    $previsao  = ""

    if ($script:baseline -and $script:baseline.ContainsKey($Name)) {
        $previsao = " - da ultima vez levou $(Format-Duration $script:baseline[$Name])"
    }

    Write-Host ""
    Write-Color "[$decorrido] $Name...$previsao" Cyan
}

function Complete-Phase {
    if (-not $script:phaseName) { return }

    $duracao = ((Get-Date) - $script:phaseStart).TotalSeconds
    $script:phaseTimings[$script:phaseName] = [math]::Round($duracao, 1)

    # Deliberadamente nao se estima o tempo TOTAL restante. O historico guarda todas as
    # etapas ja vistas, mas nem toda execucao passa por todas: uma reexecucao simples nao
    # baixa arquivos nem reconstroi imagens. Somar tudo daria um numero sempre maior que a
    # realidade, e estimativa errada mina a confianca mais do que a ausencia dela.
    Write-Color "  concluido em $(Format-Duration $duracao)" Green
    $script:phaseName = $null
}

# Tentativas limitadas: com o stdin fechado (execucao nao interativa) Read-Host retorna
# vazio de imediato, e um "while (\$true)" giraria para sempre inundando o console. Sem
# resposta valida, assume NAO - a opcao que nao altera nada.
function Ask-YesNo($Question) {
    $tentativas = 0
    while ($tentativas -lt 3) {
        $tentativas++
        $response = Read-Host "$Question (S/N)"
        if ($response -match '^(S|s|Sim|sim)$') {
            return $true
        } elseif ($response -match '^(N|n|Nao|nao|Não|não)$') {
            return $false
        } else {
            Write-Host "Resposta invalida. Por favor, responda com S ou N." -ForegroundColor Yellow
        }
    }

    Write-Host "Nenhuma resposta valida informada; assumindo NAO." -ForegroundColor Yellow
    return $false
}

# ----------------- Validacoes -----------------
function Ensure-NotOneDrive {
    # Resolve o caminho absoluto real do projeto
    $resolved = (Resolve-Path $projectRoot).Path

    # Coleta as raizes conhecidas do OneDrive a partir das variaveis de ambiente
    $oneDriveRoots = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial
    ) | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { (Resolve-Path $_).Path }

    $insideOneDrive = $false
    $sep = [System.IO.Path]::DirectorySeparatorChar

    foreach ($root in $oneDriveRoots) {
        if ($resolved -eq $root -or $resolved.StartsWith("$root$sep", [System.StringComparison]::OrdinalIgnoreCase)) {
            $insideOneDrive = $true
            break
        }
    }

    # Fallback: detecta pastas OneDrive pelo nome no caminho (ex.: "OneDrive", "OneDrive - Empresa")
    if (-not $insideOneDrive -and $resolved -match '(^|\\)OneDrive( -[^\\]*)?(\\|$)') {
        $insideOneDrive = $true
    }

    if ($insideOneDrive) {
        Write-Host ""
        Write-Color "==================== ATENCAO ====================" Red
        Write-Color "O projeto esta sendo executado dentro de uma pasta do OneDrive:" Red
        Write-Color "  $resolved" Yellow
        Write-Host ""
        Write-Color "Instalar o EduEdu+ dentro do OneDrive NAO e suportado e pode causar:" Red
        Write-Color "  - Corrupcao dos dados de Postgres/Mongo (a sincronizacao trava arquivos)" White
        Write-Color "  - Conflitos de sincronizacao e uso excessivo de banda/armazenamento" White
        Write-Color "  - Falhas nos bind mounts do Docker" White
        Write-Host ""
        Write-Color "Mova a pasta do projeto para um caminho local fora do OneDrive" Yellow
        Write-Color "(ex.: C:\eduedu) e execute a instalacao novamente." Yellow
        Write-Host ""

        if ($env:EDUEDU_ALLOW_ONEDRIVE -eq "1") {
            Write-Color "EDUEDU_ALLOW_ONEDRIVE=1 definido. Prosseguindo por sua conta e risco..." DarkYellow
            Write-Host ""
            return
        }

        Write-Color "Instalacao interrompida." Red
        Write-Host ""
        Write-Host "Pressione Enter para fechar..."
        Read-Host
        exit 1
    }
}

function Ensure-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        if(-not (Ask-YesNo "Docker nao encontrado. Deseja instalar agora?")) {
            Write-Color "Instalacao automatica interrompida. Docker e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" Red
            exit 1
        }

        Write-Color "Iniciando instalacao..." Red

        # Monta o caminho absoluto para o script de instalação
        $installScript = Join-Path $PSScriptRoot "docker-installation.ps1"

        if (Test-Path $installScript) {
            & $installScript

            Write-Color "Por favor, reinicie o processo de instalacao do projeto apos a instalacao do Docker." Yellow
            exit 0
        } else {
            Write-Color "Script de instalacao nao encontrado: $installScript" Red
            exit 1
        }
    } else {
        [void]($hasDocker = $true)
        Write-Color "Docker OK" Green
    }
}

function Ensure-WSL {
    # Monta o caminho absoluto para o script de instalação
    $installScript = Join-Path $PSScriptRoot "wsl-installation.ps1"
    if (Test-Path $installScript) {
        & $installScript
        [void]($hasWsl = $true)
    } else {
        Write-Color "Script de instalacao do WSL nao encontrado: $installScript" Red
        Write-Color "Instalacao automatica interrompida. Realize a instalacao manualmente." Red
        exit 1
    }
}

function Ensure-Winget {
    # Testa se o winget existe
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if(-not (Ask-YesNo "WinGet nao encontrado. Deseja tentar instalar agora?")) {
            Write-Color "Instalacao automatica interrompida. Winget e um pre-requisito obrigatorio, inicie o processo novamente se quiser instalar o EduEdu+" Red
            exit 1
        }
        
        Write-Color "Tentando registrar o App Installer..." Yellow
        
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        }
        catch {
            Write-Color "Erro ao tentar registrar via FamilyName." DarkYellow
        }

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Color "A primeira tentativa deu errado" Red
            Write-Color "Segunda tentativa de registrar o App Installer..." Yellow

            try {
                Install-PackageProvider -Name NuGet -Force | Out-Null
                Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
                Repair-WinGetPackageManager -Force -Latest

                Write-Color "Registro via PSGallery concluido." Green
                Write-Color "Por favor, reinicie o processo de instalacao do projeto apos a instalacao do WinGet." Yellow
                
                Write-Host ""
                Write-Host "Pressione Enter para fechar..."
                Read-Host

                exit 0
            }
            catch {
                Write-Color "Erro ao tentar registrar winget pela segunda vez. Instalacao interrompida. `n" Red
                Write-Color "Verifique se o sistema suporta WinGet (Necessario Windows 10 1809 (17763) ou superior)." Red
                
                Write-Host ""
                Write-Host "Pressione Enter para fechar..."
                Read-Host

                exit 1
            }
            
        }
    }

    # Verificação final única
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Color "WinGet ainda nao disponivel. Necessario Windows 10 1809 (17763) ou superior." Red
        Write-Color "Instalacao interrompida." Red
        exit 1
    } else {
        [void]($hasWinget = $true)
        Write-Color "WinGet OK" Green
    }
}

function Prerequisites {
    Write-Color "------------ Pre-requisitos ------------" Cyan
    Ensure-Winget
    Ensure-WSL
    Ensure-Docker
    Write-Color "----------------------------------------" Cyan
}

# ----------------- Funções Auxiliares -----------------
function Get-MachineIP {
    # Tenta pegar um IP na faixa 192.168.x.x
    $ip = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -match '^192\.168\.\d{1,3}\.\d{1,3}$' } |
        Select-Object -First 1 -ExpandProperty IPAddress

    # Se não achar, tenta 10.x.x.x
    if (-not $ip) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -match '^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    # Se ainda não achar, tenta 172.16–31.x.x
    if (-not $ip) {
        $ip = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}$' } |
            Select-Object -First 1 -ExpandProperty IPAddress
    }

    return $ip
}


function Update-EnvFile($Path, $Key, $Value) {
    $content = Get-Content $Path
    $new = @()
    $found = $false
    foreach ($line in $content) {
        if ($line -match "^$Key=") {
            $new += "$Key=$Value"
            $found = $true
        } else {
            $new += $line
        }
    }
    if (-not $found) { $new += "$Key=$Value" }
    Write-EnvLines $Path $new
}

# ----------------- Versao e Auto-atualizacao -----------------

# A versao deixa de ser um valor editado a mao no .env e passa a ser resolvida em tempo
# de execucao a partir da ultima release do repositorio. O APP_VERSION do .env passa a
# ser apenas o cache do que esta instalado nesta maquina.
#
# A atualizacao acontece SEMPRE na pasta atual. Nao existe troca de pasta, e por isso
# assets-data, mongodb-data, backup-data e o volume do Postgres permanecem no lugar.

$setupRepo = "instituto-abcd/eduedu-escola-setup"
$appRepos  = @("eduedu-escola-backend", "eduedu-escola-admin", "eduedu-escola-aluno")
$githubUA  = @{ "User-Agent" = "eduedu-escola-setup-installer" }

function Enable-Tls12 {
    # O PowerShell 5.1 nao negocia TLS 1.2 por padrao em builds mais antigos do Windows.
    # Sem isto a chamada a api.github.com falha com erro generico de conexao.
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch { }
}

function Write-EnvLines($Path, $Lines) {
    # UTF-8 sem BOM: com BOM o docker compose leria a primeira chave do arquivo com um
    # caractere invisivel no nome, e ela chegaria vazia aos containers.
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

function Import-EnvFile {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match "^\s*([^#=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"') # remove aspas duplas
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

# Acrescenta ao .env local as chaves que existem no .env de uma versao mais nova,
# preservando todos os valores ja ajustados nesta maquina. O template e o proprio .env
# que vem dentro do pacote baixado - por isso esta funcao so faz sentido durante uma
# atualizacao.
#
# E isto que evita o cenario em que imagens de uma versao nova sobem contra um .env
# antigo: v1.3.1 passou a exigir API_URL e ADMIN_URL, ausentes no .env de v1.2.1, e o
# resultado seria um portal compilado sem a URL da API - que sobe, responde 200 e nao
# funciona.
function Sync-EnvKeys($TemplatePath) {
    if (-not (Test-Path $TemplatePath)) {
        Write-Color "O pacote baixado nao trouxe um .env de referencia." DarkYellow
        Write-Color "Chaves novas desta versao podem estar ausentes no .env desta maquina." DarkYellow
        return
    }

    $existing = @{}
    foreach ($line in @(Get-Content $envPath)) {
        if ($line -match "^\s*([^#=]+)=") { $existing[$matches[1].Trim()] = $true }
    }

    $lines = @(Get-Content $envPath)
    $added = @()

    foreach ($line in @(Get-Content $TemplatePath)) {
        if ($line -match "^\s*([^#=]+)=(.*)$") {
            $key = $matches[1].Trim()
            if (-not $existing.ContainsKey($key)) {
                $lines += $line
                $existing[$key] = $true
                $added += $key
            }
        }
    }

    if ($added.Count -gt 0) {
        Write-EnvLines $envPath $lines
        Write-Color "Novas variaveis acrescentadas ao .env: $($added -join ', ')" Yellow
    }
}

# Ultima release estavel do repositorio do instalador. Retorna $null quando nao for
# possivel determinar - falha de rede NUNCA interrompe a instalacao, porque escola com
# internet instavel precisa conseguir subir a stack com as imagens que ja tem.
function Get-LatestSetupVersion {
    Enable-Tls12
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$setupRepo/releases/latest" `
            -Headers $githubUA -TimeoutSec 20
    } catch {
        # Nao dizer "versao instalada" aqui: numa maquina limpa nao ha nenhuma.
        Write-Color "Nao foi possivel verificar se ha uma versao mais nova (sem internet?)." DarkYellow
        Write-Color "A instalacao continua normalmente com a versao $env:APP_VERSION." DarkYellow
        return $null
    }

    $tag = "$($release.tag_name)".Trim()

    # /releases/latest ja exclui prerelease, mas a convencao de tag do projeto ja
    # escorregou uma vez (1.4.0-beta01, sem o "v"), por isso o formato e validado aqui.
    if ($tag -notmatch '^v\d+\.\d+(\.\d+)?$') {
        Write-Color "Nao foi possivel identificar a versao mais recente (formato inesperado: $tag)." DarkYellow
        Write-Color "A instalacao continua normalmente com a versao $env:APP_VERSION." DarkYellow
        return $null
    }

    return $tag
}

# Release mais recente INCLUINDO pre-lancamentos. So e chamada quando o opt-in esta ativo.
# Retorna $null se nao houver nenhuma valida, se a rede falhar, ou se a mais recente for a
# propria estavel (nesse caso nao faz sentido oferecer um item separado no menu).
function Get-LatestPrereleaseVersion {
    Enable-Tls12
    try {
        $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$setupRepo/releases?per_page=30" `
            -Headers $githubUA -TimeoutSec 20
    } catch {
        Write-Color "Nao foi possivel consultar as versoes de teste no GitHub." DarkYellow
        return $null
    }

    # Draft nao tem tag utilizavel. A ordenacao por published_at evita depender da ordem
    # que a API devolve; o guard final e Test-VersionIsNewer, que impede downgrade.
    $candidates = @($releases |
        Where-Object { -not $_.draft -and $_.published_at } |
        Sort-Object -Property { [datetime]$_.published_at } -Descending)

    foreach ($r in $candidates) {
        $tag = "$($r.tag_name)".Trim()

        # Formato mais permissivo que o da estavel: aceita o "v" opcional e o sufixo de
        # pre-lancamento, cobrindo tanto 1.4.0-beta01 quanto v1.3.1-rc.
        if ($tag -match '^v?\d+\.\d+(\.\d+)?(-[0-9A-Za-z.\-]+)?$') {
            return $tag
        }

        Write-Color "Release '$tag' ignorada: formato de tag nao reconhecido." DarkYellow
    }

    return $null
}

# Uma tag e considerada de pre-lancamento quando tem sufixo depois dos numeros
# (1.4.0-beta01, v1.3.1-rc). Derivar isso da propria tag, e nao da flag do GitHub, faz o
# rotulo continuar correto mesmo se alguem publicar uma beta sem marcar "prerelease".
function Test-IsPrerelease($Tag) {
    return ("$Tag" -match '^v?\d+\.\d+(\.\d+)?-')
}

# Prereleases so entram quando explicitamente habilitadas: ALLOW_PRERELEASE no .env
# (persistente, chega aqui como variavel de ambiente via Import-EnvFile) ou EDUEDU_BETA=1
# no ambiente (pontual, para nao precisar editar arquivo). O padrao e nunca oferecer beta.
function Test-PrereleaseAllowed {
    if ($env:EDUEDU_BETA -eq "1") { return $true }
    return ("$env:ALLOW_PRERELEASE" -match '^\s*(1|true|yes|sim|on)\s*$')
}

# Compara versoes tratando o sufixo de pre-lancamento pela regra do semver: com a mesma
# parte numerica, quem TEM sufixo e mais antigo (1.4.0-beta01 < 1.4.0).
#
# Sem isso o cast para [version] lancaria excecao em "1.4.0-beta01" e o catch cairia em
# comparar strings por diferenca - o que responderia "e mais nova" para qualquer tag
# diferente, inclusive uma anterior, oferecendo um downgrade.
function Test-VersionIsNewer($Current, $Target) {
    $splitTag = {
        param($Tag)
        $clean = "$Tag".Trim() -replace '^v', ''
        $parts = $clean -split '-', 2
        $num = $parts[0]
        $suffix = ""
        if ($parts.Count -gt 1) { $suffix = $parts[1] }
        return @($num, $suffix)
    }

    $c = & $splitTag $Current
    $t = & $splitTag $Target

    try {
        $cv = [version]$c[0]
        $tv = [version]$t[0]
    } catch {
        # Formato irreconhecivel: nao arriscar afirmar que e mais nova.
        return $false
    }

    if ($tv -ne $cv) { return ($tv -gt $cv) }

    # Parte numerica igual: decide o sufixo.
    if ($c[1] -and -not $t[1]) { return $true }   # beta instalada -> estavel e mais nova
    if (-not $c[1] -and $t[1]) { return $false }  # estavel instalada -> beta nao e mais nova
    if ($c[1] -and $t[1]) { return ([string]::Compare($t[1], $c[1], $true) -gt 0) }

    return $false
}

# As imagens sao construidas a partir das tags dos repositorios de aplicacao. Se a tag
# nao existir em algum deles, o build falharia com erro cru do docker no meio da
# instalacao - melhor detectar antes e manter a versao atual.
function Test-AppTagsExist($Tag) {
    Enable-Tls12
    $missing = @()

    foreach ($repo in $appRepos) {
        try {
            $null = Invoke-RestMethod -Uri "https://api.github.com/repos/instituto-abcd/$repo/git/ref/tags/$Tag" `
                -Headers $githubUA -TimeoutSec 20
        } catch {
            $missing += $repo
        }
    }

    if ($missing.Count -gt 0) {
        Write-Color "A tag $Tag nao existe em: $($missing -join ', ')" Red
        Write-Color "O build das imagens falharia. Atualizacao cancelada, versao atual mantida." Yellow
        return $false
    }

    return $true
}

function Test-ImagesUpToDate {
    if (-not $env:APP_VERSION) { return $false }

    foreach ($name in $appRepos) {
        $id = (docker images -q "${name}:$env:APP_VERSION" | Out-String).Trim()
        if (-not $id) { return $false }
    }

    return $true
}

# Snapshot antes de atualizar. "npx prisma migrate deploy" e forward-only: sem estes
# dumps nao existe caminho de volta se a versao nova apresentar problema.
function Backup-Databases {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return }

    $pgRunning = (docker ps --filter "name=^postgres$" --format "{{.Names}}" | Out-String).Trim()
    if (-not $pgRunning) {
        Write-Color "Nenhuma instalacao em execucao: snapshot pre-atualizacao dispensado." DarkYellow
        return
    }

    $stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $relative = "backup-data\pre-update-$stamp"
    $dir = Join-Path (Resolve-Path $projectRoot).Path $relative
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    Write-Color "Snapshot pre-atualizacao em $relative ..." Yellow

    docker exec postgres pg_dump -U $env:POSTGRES_USER -d $env:POSTGRES_DB -F c -f /tmp/eduedu-pg.dump 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        docker cp "postgres:/tmp/eduedu-pg.dump" (Join-Path $dir "postgres.dump") | Out-Null
        docker exec postgres rm -f /tmp/eduedu-pg.dump 2>&1 | Out-Null
        Write-Color "  postgres.dump OK" Green
    } else {
        Write-Color "  Falha ao gerar o dump do Postgres." Red
    }

    # O servico mongo nao tem container_name fixo no compose, entao o id vem do compose.
    $mongoId = (docker compose ps -q mongo 2>$null | Out-String).Trim()
    if ($mongoId) {
        docker exec $mongoId mongodump --username $env:MONGO_USER --password $env:MONGO_PASSWORD `
            --authenticationDatabase admin --archive=/tmp/eduedu-mongo.archive 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            docker cp "${mongoId}:/tmp/eduedu-mongo.archive" (Join-Path $dir "mongo.archive") | Out-Null
            docker exec $mongoId rm -f /tmp/eduedu-mongo.archive 2>&1 | Out-Null
            Write-Color "  mongo.archive OK" Green
        } else {
            Write-Color "  Falha ao gerar o dump do Mongo." Red
        }
    } else {
        Write-Color "  Container do Mongo nao encontrado, dump ignorado." DarkYellow
    }

    Write-EnvLines (Join-Path $dir "versao-anterior.txt") @($env:APP_VERSION)
}

# Baixa o pacote da tag e aplica sobre a pasta atual, preservando configuracao e dados.
function Update-SetupFiles($Tag) {
    $root = (Resolve-Path $projectRoot).Path
    $zip  = Join-Path $env:TEMP "eduedu-setup-$Tag.zip"
    $tmp  = Join-Path $env:TEMP "eduedu-setup-$Tag"

    if (Test-Path $zip) { Remove-Item $zip -Force }
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

    Write-Color "Baixando os arquivos da versao $Tag..." Yellow
    Enable-Tls12
    try {
        Invoke-WebRequest -Uri "https://github.com/$setupRepo/archive/refs/tags/$Tag.zip" `
            -OutFile $zip -TimeoutSec 300 -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
    } catch {
        Write-Color "Falha ao baixar a versao $Tag." Red
        Write-Color "A versao instalada ($env:APP_VERSION) sera mantida." Yellow
        return $false
    }

    $source = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $source) {
        Write-Color "O pacote baixado esta vazio. Atualizacao cancelada." Red
        return $false
    }

    # .env fica de fora para nao descartar a configuracao da maquina; os diretorios de
    # dados nem vem no pacote, mas sao excluidos por seguranca. Instalador-Windows.cmd
    # tambem fica de fora: o cmd.exe le arquivos .cmd linha a linha e sobrescrever um
    # em execucao corrompe o fluxo.
    $roboArgs = @(
        $source.FullName, $root, "/E", "/R:2", "/W:2",
        "/NFL", "/NDL", "/NJH", "/NJS", "/NP",
        "/XF", ".env", "Instalador-Windows.cmd",
        "/XD", "assets-data", "mongodb-data", "postgres-data", "backup-data", ".git"
    )
    & robocopy.exe @roboArgs | Out-Null

    # robocopy usa 0-7 para sucesso e >=8 para falha real. Note que nao ha /MIR nem
    # /PURGE: arquivos que existem apenas na maquina nunca sao apagados.
    if ($LASTEXITCODE -ge 8) {
        Write-Color "Falha ao aplicar os arquivos da versao $Tag (robocopy $LASTEXITCODE)." Red
        return $false
    }

    # robocopy sinaliza sucesso com codigo diferente de zero; sem isto o proximo
    # "if ($LASTEXITCODE -ne 0)" do script interpretaria o sucesso como falha.
    $global:LASTEXITCODE = 0

    # Chaves novas trazidas por esta versao entram no .env antes de qualquer build. O
    # template e o .env do pacote, que o robocopy deixou de fora justamente para nao
    # sobrescrever a configuracao desta maquina.
    # Precisa vir ANTES da limpeza do diretorio temporario, que e onde esse .env esta.
    Sync-EnvKeys (Join-Path $source.FullName ".env")
    Update-EnvFile $envPath "APP_VERSION" $Tag

    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zip -Force -ErrorAction SilentlyContinue

    Write-Color "Arquivos da versao $Tag aplicados." Green
    return $true
}

# Leva a instalacao para uma versao mais nova: baixa os arquivos daquela tag, mescla as
# chaves novas do .env, grava APP_VERSION e reexecuta o instalador ja atualizado.
#
# Os arquivos do setup mudam em toda transicao de versao - v1.3.1 passou a exigir API_URL
# e ADMIN_URL, removeu RABBITMQ_URI e renomeou build-args -, entao trocar so APP_VERSION
# construiria imagens novas com orquestracao velha. Por isso a atualizacao traz os dois.
#
# Vale APENAS para frente. Ir para uma versao anterior e bloqueado: "prisma migrate
# deploy" e forward-only, e reverter as imagens contra um banco ja migrado quebraria a
# instalacao. Alem disso, rebaixar o instalador junto levaria a scripts que nao conhecem
# este fluxo - foi o que se observou ao instalar a v1.3.1 a partir de uma beta.
function Set-TargetVersion($Tag) {
    if (-not (Test-VersionIsNewer $env:APP_VERSION $Tag)) {
        Write-Host ""
        if ($Tag -eq $env:APP_VERSION) {
            Write-Color "A versao $Tag ja e a atual - nao ha o que atualizar." Yellow
        } else {
            Write-Color "A versao $Tag e anterior a atual ($env:APP_VERSION)." Red
            Write-Color "Voltar para uma versao anterior nao e suportado: o banco de dados ja" Red
            Write-Color "pode ter sido atualizado e nao consegue voltar atras sozinho." Red
            Write-Color "Se precisar disso, procure o suporte do Instituto ABCD." Yellow
        }
        return $false
    }

    # Sao tres chamadas de API em sequencia, cada uma com ate 20s de timeout: sem
    # anunciar, sao ate um minuto de tela parada logo apos o usuario escolher.
    Start-Phase "Verificando a versao $Tag"
    if (-not (Test-AppTagsExist $Tag)) { return $false }
    Complete-Phase

    Start-Phase "Fazendo copia de seguranca dos dados"
    Backup-Databases
    Complete-Phase

    Start-Phase "Baixando os arquivos da versao $Tag"
    if (-not (Update-SetupFiles $Tag)) { return $false }
    Complete-Phase

    # As etapas acima acontecem neste processo e as de instalacao no processo reexecutado;
    # gravar aqui garante que ambas entrem no historico usado como estimativa.
    Save-Baseline

    # Reexecuta o instalador recem-baixado para que a logica da versao nova valha ja nesta
    # rodada. O PowerShell carrega o script inteiro em memoria, entao sobrescrever este
    # arquivo enquanto ele roda e seguro.
    #
    # EDUEDU_ACTION carrega a escolha ja feita, para o usuario nao decidir duas vezes, e
    # serve de guarda contra loop: com ela definida, Show-MainMenu retorna antes de
    # consultar versao, entao o processo filho nunca dispara outra atualizacao.
    $novo = Join-Path $PSScriptRoot "startup-windows.ps1"
    if (-not (Select-String -Path $novo -Pattern 'EDUEDU_ACTION' -Quiet)) {
        # Salvaguarda para combinacoes nao previstas: se o script baixado nao conhece o
        # protocolo, ele vai reapresentar o proprio menu. Melhor avisar do que deixar o
        # usuario sem contexto.
        Write-Host ""
        Write-Color "O instalador da versao $Tag e anterior a este fluxo e vai reiniciar" DarkYellow
        Write-Color "do proprio jeito - ele pode perguntar novamente o que voce deseja fazer." DarkYellow
    }

    Write-Host ""
    Write-Color "Instalador atualizado para $Tag. Retomando a instalacao..." Cyan
    Write-Host ""

    $env:EDUEDU_ACTION = "update"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $novo
    exit $LASTEXITCODE
}

# ----------------- Build de Imagens -----------------

function Build-Images {
    Write-Color "------- Buildando Imagens -------" Cyan

    # Sem isto todo duplo clique custaria tres builds completos a partir do GitHub,
    # mesmo quando nada mudou.
    if ($script:skipBuild) {
        Write-Color "Imagens ja presentes na versao $env:APP_VERSION e IP inalterado." Green
        Write-Color "Build ignorado." Green
        Write-Color "---------------------------------" Cyan
        return
    }

    Write-Color "Buildando backend ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-backend:$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-backend.git#$env:APP_VERSION"

    Write-Color "Buildando admin ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-admin:$env:APP_VERSION" `
        --build-arg "API_URL=$env:API_URL" `
        --build-arg "APP_VERSION=$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-admin.git#$env:APP_VERSION"

    Write-Color "Buildando aluno ($env:APP_VERSION)..." Yellow
    docker build -t "eduedu-escola-aluno:$env:APP_VERSION" `
        --build-arg "API_URL=$env:API_URL" `
        --build-arg "ADMIN_URL=$env:ADMIN_URL" `
        --build-arg "APP_VERSION=$env:APP_VERSION" `
        "https://github.com/instituto-abcd/eduedu-escola-aluno.git#$env:APP_VERSION"

    Write-Color "---------------------------------" Cyan
}

# ----------------- Containers -----------------

function Get-PostgresImage {
    if ($env:POSTGRES_IMAGE) { return $env:POSTGRES_IMAGE }
    return "postgres:17.6"   # mantenha em sincronia com o default do docker-compose.yml
}

# Descobre o volume que o compose realmente monta em /var/lib/postgresql/data.
# O compose prefixa volumes nomeados com o nome do projeto (ex.: setup_pgdata),
# por isso o nome nunca deve ser assumido como "pgdata".
function Get-PostgresVolume {
    docker compose create postgres 2>&1 | Out-Null
    $volume = docker inspect postgres --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}'
    return ($volume | Out-String).Trim()
}

# Restaura um snapshot de ./postgres-data ANTES do primeiro start do Postgres.
# Copiar arquivos com o container no ar sobrescreve o cluster durante o initdb e
# quebra roles/pg_hba.conf - foi o que gerava o erro "denied access on the database".
function Restore-PostgresSnapshot {
    $snapshot = Join-Path (Resolve-Path $projectRoot).Path "postgres-data"

    if (-not (Test-Path $snapshot)) { return }

    if ($script:installAction -eq "install") {
        Write-Color "Instalacao limpa: snapshot em ./postgres-data sera ignorado (banco criado do zero)." Yellow
        Write-Color "Se quiser aproveitar esses dados, escolha a opcao de atualizacao." Yellow
        return
    }

    if (-not (Test-Path (Join-Path $snapshot "PG_VERSION"))) {
        Write-Color "A pasta ./postgres-data existe mas nao contem um cluster valido (PG_VERSION ausente)." DarkYellow
        Write-Color "Restauracao ignorada - o Postgres sera inicializado do zero." DarkYellow
        return
    }

    $image  = Get-PostgresImage
    $volume = Get-PostgresVolume

    if (-not $volume) {
        Write-Color "Nao foi possivel identificar o volume de dados do Postgres. Restauracao ignorada." DarkYellow
        return
    }

    # Nao sobrescreve um cluster existente (caminho de atualizacao)
    $hasCluster = (docker run --rm -v "${volume}:/target" --entrypoint sh $image -c "[ -f /target/PG_VERSION ] && echo yes || echo no" | Out-String).Trim()
    if ($hasCluster -eq "yes") {
        Write-Color "Volume $volume ja possui um cluster. Snapshot de ./postgres-data ignorado (dados atuais preservados)." Yellow
        return
    }

    # Major version do snapshot precisa casar com a da imagem
    $snapshotMajor = (Get-Content (Join-Path $snapshot "PG_VERSION") -Raw).Trim()
    $imageMajor    = ((docker run --rm --entrypoint postgres $image --version | Out-String) -replace '[^0-9\. ]', '').Trim().Split(' ')[-1].Split('.')[0]

    if ($snapshotMajor -ne $imageMajor) {
        Write-Color "Snapshot em ./postgres-data e do PostgreSQL $snapshotMajor, mas a imagem e a $imageMajor." Red
        Write-Color "Restaurar dados entre versoes maiores diferentes nao funciona." Red
        Write-Color "Opcoes: definir POSTGRES_IMAGE=postgres:$snapshotMajor no .env, ou remover/renomear ./postgres-data." Yellow
        exit 1
    }

    Write-Color "Restaurando snapshot de ./postgres-data no volume $volume..." Yellow
    docker run --rm -v "${volume}:/target" -v "${snapshot}:/snapshot:ro" --entrypoint sh $image `
        -c "cp -a /snapshot/. /target/ && chown -R postgres:postgres /target && chmod 700 /target"

    if ($LASTEXITCODE -ne 0) {
        Write-Color "Falha ao restaurar o snapshot do Postgres." Red
        exit 1
    }
}

# Testa exatamente o caminho que o backend usa: TCP, via rede do Docker,
# com usuario/senha/database do .env (valida senha, role e pg_hba.conf).
function Test-PostgresAccess {
    $network = (docker inspect postgres --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' | Out-String).Trim().Split(' ')[0]
    if (-not $network) { return $false }

    $null = docker run --rm --network $network -e "PGPASSWORD=$env:POSTGRES_PASSWORD" --entrypoint psql (Get-PostgresImage) `
        -h postgres -p 5432 -U $env:POSTGRES_USER -d $env:POSTGRES_DB -c "SELECT 1" 2>&1

    return ($LASTEXITCODE -eq 0)
}

function Wait-Postgres {
    Write-Host "`n[ - ] Aguardando o Postgres aceitar conexoes:" -ForegroundColor Yellow

    $maxRetries = 30
    $attempt = 1

    while ($attempt -le $maxRetries) {
        if (Test-PostgresAccess) {
            Write-Host "[ OK ] Postgres pronto ($env:POSTGRES_USER@$env:POSTGRES_DB)`n" -ForegroundColor Green
            return
        }

        Write-Host "[ Tentativa $attempt/$maxRetries ] Postgres ainda nao aceitou a conexao..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        $attempt++
    }

    Write-Host ""
    Write-Color "[ ERRO ] O Postgres subiu mas recusou a conexao de $env:POSTGRES_USER em $env:POSTGRES_DB." Red
    Write-Color "Sem isso o backend falha com 'denied access on the database'. Instalacao interrompida." Red
    Write-Host ""
    Write-Color "Causa mais comum: volume de dados de uma instalacao anterior, com senha/database diferentes" Yellow
    Write-Color "do .env atual (POSTGRES_DB/POSTGRES_USER/POSTGRES_PASSWORD so valem quando o volume esta vazio)." Yellow
    Write-Color "Para recriar o banco do zero (apaga os dados atuais): docker compose down -v" Yellow
    Write-Host ""
    Write-Color "Ultimas linhas do log do Postgres:" Yellow
    docker logs postgres --tail 30

    exit 1
}

function Wait-Mongo {
    Write-Host "`n[ - ] Aguardando o Mongo aceitar conexoes:" -ForegroundColor Yellow

    $id = (docker compose ps -q mongo 2>$null | Out-String).Trim()
    if (-not $id) {
        Write-Color "[ AVISO ] Container do Mongo nao encontrado; seguindo adiante." DarkYellow
        return
    }

    $maxRetries = 30
    $attempt = 1

    while ($attempt -le $maxRetries) {
        $null = docker exec $id mongosh --quiet --username $env:MONGO_USER --password $env:MONGO_PASSWORD `
            --authenticationDatabase admin --eval "db.adminCommand('ping')" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[ OK ] Mongo pronto`n" -ForegroundColor Green
            return
        }

        Write-Host "[ Tentativa $attempt/$maxRetries ] Mongo ainda nao aceitou a conexao..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        $attempt++
    }

    Write-Color "[ AVISO ] O Mongo demorou mais que o esperado. A instalacao continua." DarkYellow
}

function Compose-Containers {
    Push-Location $projectRoot

    Write-Color "------- Subindo Containers -------" Cyan

    Restore-PostgresSnapshot

    # Sem --quiet-pull: o download das imagens base soma centenas de MB e, silenciado,
    # e o trecho que mais passa sensacao de travamento numa conexao lenta. O progresso
    # do proprio Docker e a melhor indicacao disponivel aqui.
    docker compose up -d postgres
    Wait-Postgres

    docker compose up -d mongo
    # Antes era um Start-Sleep fixo de 15s: parado na tela e, em maquina lenta, curto
    # demais. Agora espera o banco responder de fato, mostrando cada tentativa.
    Wait-Mongo

    # migration e backend esperam o healthcheck do postgres (docker-compose.yml)
    docker compose up -d

    Write-Color "----------------------------------" Cyan

    Pop-Location
}

# ----------------- Validações HTTP -----------------
function Validate-Service($Name, $Url) {
    Write-Host "`n[ - ] Verificando $( $Name ):" -ForegroundColor Yellow
    $maxRetries = 20 
    $attempt = 1

    while ($attempt -le $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "[ Tentativa $attempt/$maxRetries ] $Name requisicao concluida com sucesso" -ForegroundColor Yellow
                Write-Host "[ OK ] $Name `n" -ForegroundColor Green
                return
            }
        } catch {
            Write-Host "[ Tentativa $attempt/$maxRetries ] $Name ainda nao respondeu..." -ForegroundColor Yellow
        }

        Start-Sleep -Seconds 5
        $attempt++
    }

    Write-Host "[ ERRO ] $Name nao respondeu em $Url `n" -ForegroundColor Red
    exit 1
}

function Init-Services {
    Write-Color "------- Validacao de Servicos -------" Cyan
    
    Validate-Service "Backend API"    "http://127.0.0.1:$env:API_PORT/swagger"
    Validate-Service "Portal Admin"   "http://127.0.0.1:$env:ADMIN_PORT"
    Validate-Service "Portal Aluno"   "http://127.0.0.1:$env:ALUNO_PORT"

    Write-Color "-------------------------------------" Cyan
}

# ----------------- Instalação/Atualização -----------------
function Remove-ImageIfExists($Repository) {
    $ids = docker images -q $Repository
    if ($ids) { docker rmi -f $ids | Out-Null }
}

function Stop-CurrentContainers($Action) {
    # Sempre "docker compose" (plugin v2). O binario legado "docker-compose" nao existe
    # em instalacoes recentes do Docker Desktop: se ele falhar aqui, os volumes antigos
    # sobrevivem a uma instalacao limpa e o banco continua com a senha/database anteriores.
    switch ($Action) {
        "install" {
            Write-Color "Parando containers e removendo imagens e volumes" Yellow
            docker compose down --rmi all --volumes --remove-orphans

            if ($LASTEXITCODE -ne 0) {
                Write-Color "Falha ao remover containers/volumes da instalacao anterior." Red
                Write-Color "Prosseguir manteria o banco antigo e causaria erro de acesso no backend." Red
                Write-Color "Rode 'docker compose down --rmi all --volumes --remove-orphans' manualmente e tente de novo." Yellow
                exit 1
            }
        }
        "update" {
            Write-Color "Parando containers" Yellow
            docker compose down --remove-orphans

            if ($LASTEXITCODE -ne 0) {
                Write-Color "Falha ao parar os containers atuais." Red
                exit 1
            }

            # admin e aluno tem API_URL/ADMIN_URL compilados na imagem, entao precisam
            # ser reconstruidas quando o IP da maquina muda - mesmo sem troca de versao.
            # Quando nada mudou, remove-las forcaria um rebuild inutil.
            if ($script:skipBuild) {
                Write-Color "Imagens atuais serao reaproveitadas (versao e IP inalterados)." Green
            } else {
                Remove-ImageIfExists "eduedu-escola-admin"
                Remove-ImageIfExists "eduedu-escola-aluno"
            }
        }
        default {
            Write-Color "Acao invalida" Red
            exit 1
        }
    }
}

# Detecta instalacao anterior no escopo DESTE projeto compose, e nao em qualquer coisa
# que exista no Docker da maquina.
function Test-ExistingInstallation {
    $containers = (docker compose ps -aq 2>$null | Out-String).Trim()
    if ($containers) { return $true }

    # O volume do Postgres sobrevive a um "compose down" sem -v, entao ele tambem indica
    # instalacao anterior. O nome real e prefixado pelo nome do projeto, e o filtro do
    # docker casa por substring: sem ancorar em ^...$ e sem o prefixo do projeto, o
    # pgdata de QUALQUER outro projeto na mesma maquina seria contado como se fosse desta
    # instalacao.
    $project = ""
    try {
        $project = (docker compose config --format json 2>$null | ConvertFrom-Json).name
    } catch { }

    if ($project) {
        $volume = (docker volume ls -q --filter "name=^${project}_pgdata$" 2>$null | Out-String).Trim()
        if ($volume) { return $true }
    }

    return $false
}

# Menu unico: e aqui que TODA decisao acontece. A consulta de versao apenas informa;
# nenhum download ocorre sem escolha explicita do usuario.
function Show-MainMenu {
    $script:installAction = "install"

    # A escolha ja foi feita antes da reexecucao pos-atualizacao; nao perguntar de novo.
    if ($env:EDUEDU_ACTION -eq "update") {
        Write-Color "Concluindo a instalacao escolhida..." Yellow
        if (Test-ExistingInstallation) {
            $script:installAction = "update"
            Stop-CurrentContainers update
        } else {
            # Sem instalacao anterior o banco nasce do zero. Manter "install" evita que um
            # ./postgres-data solto na pasta seja restaurado sem o usuario pedir.
            $script:installAction = "install"
        }
        # A versao mudou, entao as imagens antigas nao servem.
        $script:skipBuild = $false
        return
    }

    $current    = $env:APP_VERSION
    $hasInstall = Test-ExistingInstallation
    $latest     = Get-LatestSetupVersion
    $canUpdate  = $latest -and (Test-VersionIsNewer $current $latest)

    # Pre-lancamentos so sao consultados sob opt-in. Nunca substituem a versao estavel no
    # menu: quando existem, aparecem como um item ADICIONAL e rotulado.
    $prerelease = $null
    $canPre     = $false
    if (Test-PrereleaseAllowed) {
        $prerelease = Get-LatestPrereleaseVersion
        $canPre = $prerelease -and ($prerelease -ne $latest) -and (Test-VersionIsNewer $current $prerelease)
    }

    # O opt-in impede ATUALIZAR para uma beta, mas nao impede que o pacote baixado ja SEJA
    # uma beta - basta pegar o zip errado na pagina de releases. Sem tratamento, a escola
    # instalaria uma versao de teste sem nunca ser avisada.
    #
    # Quem ligou ALLOW_PRERELEASE escolheu isso de proposito e nao precisa do alarme.
    $pacoteEhTeste = (Test-IsPrerelease $current) -and (-not (Test-PrereleaseAllowed))

    # Nao se oferece trocar por uma estavel anterior. Ir para tras nao e suportado: o
    # banco e forward-only e o instalador seria rebaixado junto. Quem baixou o pacote
    # errado e orientado a baixar o certo, que e a unica saida correta.
    $temEstavelAnterior = $pacoteEhTeste -and $latest -and ($latest -ne $current)

    # As acoes sao montadas em ordem para que os numeros do menu nunca sejam fixos:
    # cada item de atualizacao so existe quando ha de fato uma versao mais nova.
    # O texto e escrito para quem opera a maquina na escola, nao para quem desenvolve:
    # sem "pacote", "release" ou "prerelease", e sem "reiniciar" sozinho, que se confunde
    # com reiniciar o computador.
    $actions = @()

    # A dica sobre preservar dados so faz sentido quando existe algo a preservar: numa
    # maquina limpa ela confunde em vez de tranquilizar.
    if ($canUpdate) {
        $texto = if ($hasInstall) { "Atualizar para $latest" } else { "Instalar a versao mais recente ($latest)" }
        $dica  = if ($hasInstall) { "mantem todos os dados, arquivos e backups" } else { "" }
        $actions += @{ Key = "update"; Tag = $latest; Text = $texto; Hint = $dica }
    }
    if ($canPre) {
        $texto = if ($hasInstall) { "Atualizar para $prerelease" } else { "Instalar $prerelease" }
        $actions += @{ Key = "update"; Tag = $prerelease; Text = "$texto  [VERSAO DE TESTE]"; Hint = "ainda em teste - nao use no computador da escola" }
    }
    if ($hasInstall) {
        $actions += @{ Key = "restart"; Tag = $current; Text = "Iniciar o EduEdu+ novamente ($current)"; Hint = "mantem todos os dados" }
        $actions += @{ Key = "clean";   Tag = $current; Text = "Instalar do zero - APAGA TODOS OS DADOS"; Hint = "" }
    } else {
        $rotulo = if ($pacoteEhTeste) { "Instalar $current mesmo assim  [VERSAO DE TESTE]" } else { "Instalar agora ($current)" }
        $dica   = if ($pacoteEhTeste) { "ainda em teste - pode apresentar falhas" } else { "" }
        $actions += @{ Key = "restart"; Tag = $current; Text = $rotulo; Hint = $dica }
    }
    $actions += @{ Key = "exit"; Tag = ""; Text = "Sair sem fazer nada"; Hint = "" }

    Write-Host ""
    Write-Color "------------ EduEdu+ Escola ------------" Cyan

    # APP_VERSION e a versao que acompanha o instalador, e so coincide com a instalada
    # quando existe instalacao. Numa maquina limpa, chamar isso de "versao instalada" e
    # falso - e e justamente o que alguem le antes de decidir apagar dados.
    if ($hasInstall) {
        Write-Color "Versao instalada neste computador: $current" White

        if ($canUpdate) {
            Write-Color "Versao mais recente disponivel   : $latest" Yellow
        } elseif ($latest) {
            Write-Color "Nao ha atualizacao disponivel." Green
        }

        if ($pacoteEhTeste) {
            # Aqui NAO se oferece a troca por uma estavel anterior: o banco ja pode ter
            # sido migrado por esta versao, e voltar quebraria a instalacao. O aviso diz
            # a verdade em vez de oferecer um caminho perigoso.
            Write-Host ""
            Write-Color "ATENCAO: este computador esta com uma versao de teste ($current)." DarkYellow
            Write-Color "Versoes de teste podem apresentar falhas e nao sao indicadas para" DarkYellow
            Write-Color "o computador que a escola usa no dia a dia." DarkYellow
            Write-Color "Para voltar a uma versao normal sem perder dados, procure o suporte" DarkYellow
            Write-Color "do Instituto ABCD - a troca exige cuidados com o banco de dados." DarkYellow
        }
    } else {
        Write-Color "O EduEdu+ ainda nao esta instalado neste computador." DarkGray

        if ($pacoteEhTeste) {
            Write-Host ""
            Write-Color "ATENCAO: o instalador que voce baixou traz a versao $current," DarkYellow
            Write-Color "que ainda esta em teste e pode apresentar falhas." DarkYellow
            Write-Host ""
            if ($temEstavelAnterior) {
                Write-Color "A versao indicada para a escola e a $latest." White
            }
            # O instalador nao pode instalar uma versao anterior por conta propria, entao a
            # orientacao precisa ser acionavel: baixar o pacote certo.
            Write-Color "Para usar na escola, baixe o instalador novamente escolhendo a" White
            Write-Color "versao marcada como 'Latest' em:" White
            Write-Color "  https://github.com/$setupRepo/releases/latest" Cyan
        } elseif ($canUpdate) {
            Write-Color "Versao que acompanha o instalador: $current" DarkGray
            Write-Color "Versao mais recente disponivel   : $latest" Yellow
        } else {
            # Sem instalacao e sem nada mais novo, so importa o que sera instalado.
            # Mencionar outras versoes aqui seria ruido para quem opera a maquina.
            Write-Color "Versao que sera instalada: $current" White
        }
    }

    if (Test-PrereleaseAllowed) {
        Write-Color "Versoes de teste estao habilitadas neste computador." DarkYellow
    }
    Write-Host ""

    for ($i = 0; $i -lt $actions.Count; $i++) {
        Write-Color ("  {0}. {1}" -f ($i + 1), $actions[$i].Text) White
        if ($actions[$i].Hint) { Write-Color ("     {0}" -f $actions[$i].Hint) DarkGray }
    }
    Write-Host ""

    # Tentativas limitadas: um erro de digitacao merece nova chance, mas sem laco infinito.
    # Se o stdin estiver fechado (execucao nao interativa), Read-Host retorna vazio de
    # imediato e um "while" sem limite giraria para sempre inundando o console.
    $selected = $null
    $attempts = 0
    while (-not $selected -and $attempts -lt 3) {
        $attempts++
        $opt = Read-Host "Escolha uma opcao"
        $n = 0
        if ([int]::TryParse($opt, [ref]$n) -and $n -ge 1 -and $n -le $actions.Count) {
            $selected = $actions[$n - 1]
        } else {
            Write-Color "Opcao invalida. Digite um numero entre 1 e $($actions.Count)." Yellow
        }
    }

    if (-not $selected) {
        Write-Color "Nenhuma opcao valida informada. Nada foi alterado." Yellow
        exit 1
    }

    # Confirmacao para QUALQUER caminho que resulte em instalar uma versao de teste -
    # inclusive a que veio no proprio pacote, que nao passa por Set-TargetVersion.
    # Fica de fora apenas religar uma instalacao de teste ja existente: nada novo e
    # instalado ali, e avisar a cada execucao viraria ruido que se aprende a ignorar.
    $vaiInstalarTeste = ($selected.Key -ne "exit") -and (Test-IsPrerelease $selected.Tag)
    if ($selected.Key -eq "restart" -and $hasInstall) { $vaiInstalarTeste = $false }

    if ($vaiInstalarTeste) {
        Write-Host ""
        Write-Color "A versao $($selected.Tag) ainda esta em teste e pode apresentar falhas." DarkYellow
        Write-Color "Ela nao deve ser usada no computador que a escola utiliza no dia a dia." DarkYellow
        Write-Host ""
        if (-not (Ask-YesNo "Tem certeza que deseja instalar esta versao de teste?")) {
            Write-Color "Nada foi alterado." Green
            exit 0
        }
    }

    # A tag vem da acao escolhida, e nao de uma variavel externa: com estavel e versao de
    # teste no mesmo menu, usar $latest aqui instalaria a versao errada.
    switch ($selected.Key) {
        "update" {
            if (-not (Set-TargetVersion $selected.Tag)) {
                Write-Color "A troca de versao nao foi concluida. Nenhuma alteracao foi feita." Yellow
                Write-Host ""
                Write-Host "Pressione Enter para fechar..."
                Read-Host
                exit 1
            }

            # A versao mudou, entao as imagens atuais nao servem mais - nem as de admin e
            # aluno, que compilam as URLs. Sem zerar skipBuild, Build-Images seria pulado
            # e a stack subiria na versao antiga.
            $script:skipBuild = $false

            if ($hasInstall) {
                $script:installAction = "update"
                Stop-CurrentContainers update
            } else {
                $script:installAction = "install"
            }
        }
        "restart" {
            if ($hasInstall) {
                # "update" preserva os volumes e permite que Restore-PostgresSnapshot
                # aproveite um ./postgres-data existente.
                $script:installAction = "update"
                Stop-CurrentContainers update
            } else {
                # Sem instalacao anterior o banco nasce do zero: manter "install" evita
                # que um ./postgres-data solto na pasta seja restaurado sem o usuario pedir.
                $script:installAction = "install"
            }
        }
        "clean" {
            Write-Host ""
            Write-Color "Esta opcao APAGA o banco de dados, os arquivos enviados pelo painel" Red
            Write-Color "e os backups desta instalacao. A acao nao pode ser desfeita." Red
            Write-Host ""
            $c = Read-Host "Para confirmar, digite APAGAR"
            if ($c -cne "APAGAR") {
                Write-Color "Confirmacao nao recebida. Nada foi alterado." Green
                exit 0
            }
            # "install" roda "docker compose down --rmi all": as imagens deixam de existir.
            # skipBuild foi calculado antes disso, quando elas ainda estavam la - manter o
            # valor antigo pularia o build e o compose subiria sem imagem para usar.
            $script:skipBuild = $false
            $script:installAction = "install"
            Stop-CurrentContainers install
        }
        "exit" { exit 0 }
    }
}

# ----------------- Main -----------------
function Main {
    Start-Run
    $start = $script:runStart

    # Bloqueia execucao dentro de pastas do OneDrive (antes de qualquer alteracao)
    Ensure-NotOneDrive

    if (-not (Test-Path $envPath)) {
        Write-Color "Arquivo .env nao encontrado em $projectRoot." Red
        Write-Color "Baixe o pacote de instalacao novamente - ele acompanha o .env." Red
        exit 1
    }

    Import-EnvFile

    # MONGO_URI e DATABASE_URL sao usadas de dentro da rede do Docker, onde as portas
    # sao sempre as internas (27017 e 5432). POSTGRES_PORT/MONGO_PORT valem apenas
    # para o mapeamento no host.

    # Atualiza MONGO_URI
    Update-EnvFile ".env" "MONGO_URI" "mongodb://${env:MONGO_USER}:${env:MONGO_PASSWORD}@mongo:27017/eduedu?authSource=admin"


    # Atualiza DATABASE_URL
    Update-EnvFile ".env" "DATABASE_URL" "postgresql://${env:POSTGRES_USER}:${env:POSTGRES_PASSWORD}@postgres:5432/${env:POSTGRES_DB}?schema=public"

    Start-Phase "Verificando os programas necessarios"
    Prerequisites
    Complete-Phase

    # O IP e resolvido antes do menu porque Stop-CurrentContainers precisa saber se as
    # imagens de admin/aluno ainda servem: elas compilam API_URL/ADMIN_URL.
    $ip = Get-MachineIP
    Write-Color "IP detectado: $ip" Yellow
    $script:ipChanged = ($env:APP_ADDRESS -ne $ip)
    $script:skipBuild = (-not $script:ipChanged) -and (Test-ImagesUpToDate)

    # Unico ponto de decisao do instalador. A consulta de versao acontece aqui e apenas
    # informa; atualizar e uma escolha do usuario, nunca um efeito colateral.
    Show-MainMenu

    Update-EnvFile ".env" "FILE_SERVER_URL" "http://${ip}:$($env:API_PORT)/assets-data"
    Update-EnvFile ".env" "APP_ADDRESS" "${ip}"
    Update-EnvFile ".env" "APP_URL"       "http://${ip}"
    Update-EnvFile ".env" "API_URL"       "http://${ip}:$($env:API_PORT)"
    Update-EnvFile ".env" "ADMIN_URL"     "http://${ip}:$($env:ADMIN_PORT)"


    Import-EnvFile

    Start-Phase "Preparando os programas do EduEdu+"
    Build-Images
    Complete-Phase

    Start-Phase "Iniciando os servicos"
    Compose-Containers
    Complete-Phase

    Start-Phase "Conferindo se tudo respondeu"
    Init-Services
    Complete-Phase

    # Grava os tempos desta execucao para servir de estimativa na proxima.
    Save-Baseline

    $execTime = Format-Duration ((Get-Date) - $start).TotalSeconds

    Write-Host ""
    Write-Color "EduEdu Escola - Versao $env:APP_VERSION - concluido em $execTime `n" Green
    Write-Color "`n--> Link de acesso Portal Admin: http://$( $ip ):$env:ADMIN_PORT" White
    Write-Color "--> Link de acesso portal Aluno: http://$( $ip ):$env:ALUNO_PORT `n" White
}

Main
Write-Host ""
Write-Host "Pressione Enter para fechar..."
Read-Host
