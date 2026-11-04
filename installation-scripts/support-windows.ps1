# EduEdu+ - Coleta de dados para suporte (Windows)
# ----------------------------------------------------------------------
# Reune informacoes da instalacao atual e gera um log (.txt) para anexar a
# tickets de suporte. Roda manualmente, como o instalador, pelo
# Suporte-Windows.cmd na raiz do projeto. O arquivo e gravado em
# logs\log_<data de geracao>.txt.
#
# Somente leitura: nao altera containers, imagens, volumes, .env nem a rede.
#
# Cada verificacao fica em um arquivo proprio em support-checks\, executado
# em ordem alfabetica (por isso o prefixo numerico: 10-, 20-, ...). Para
# incluir uma verificacao basta criar um arquivo nessa pasta usando as
# funcoes das secoes "Log", "Comandos externos" e "Rede" abaixo. Um erro em
# uma verificacao fica registrado no log e nao impede as demais.

param(
    # Nao copia o log para a area de transferencia, nao abre o Explorer e nao
    # espera Enter no final
    [switch]$Silencioso
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$envPath     = Join-Path $projectRoot ".env"
$checksDir   = Join-Path $PSScriptRoot "support-checks"
$logDir      = Join-Path $projectRoot "logs"

$generatedAt = Get-Date
$logLines    = New-Object System.Collections.Generic.List[string]

# ----------------- Utilitarios -----------------

function Write-Color($Text, $Color = "White") {
    Write-Host $Text -ForegroundColor $Color
}

# Le o .env sem exportar nada para o ambiente do processo
function Read-EnvFile($Path) {
    $values = @{}
    if (-not (Test-Path $Path)) { return $values }

    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*([^#=]+)=(.*)$') {
            $values[$matches[1].Trim()] = $matches[2].Trim().Trim('"')
        }
    }
    return $values
}

$envValues = Read-EnvFile $envPath

# Quebra um texto em linhas, sem espacos nas pontas e sem linhas vazias
function ConvertTo-Lines($Text) {
    @("$Text" -split "\r?\n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# ----------------- Log -----------------

# Titulo de secao. Tambem mostra o andamento na tela.
function Write-LogSection($Title) {
    if ($logLines.Count -gt 0) { $logLines.Add("") }
    $logLines.Add("[ $Title ]")
    Write-Color "[ - ] $Title" Yellow
}

# Linha "Rotulo : valor", com os rotulos alinhados
function Write-LogItem($Label, $Value) {
    $logLines.Add(("{0,-34}: {1}" -f $Label, $Value))
}

# Texto livre, como a saida de um comando, recuado para se destacar dos itens
function Write-LogText($Text) {
    $content = ($Text | Out-String).TrimEnd()
    if (-not $content) {
        $logLines.Add("    (vazio)")
        return
    }
    foreach ($line in $content -split "\r?\n") { $logLines.Add("    $line") }
}

# O log e feito para ser compartilhado: esconde as senhas do .env e a senha
# de qualquer URL com credenciais (postgresql://, mongodb://, redis://...)
function Protect-Secrets([string]$Text) {
    foreach ($key in $envValues.Keys) {
        $value = $envValues[$key]
        if ($key -match 'PASSWORD|SECRET|TOKEN|_KEY$' -and $value.Length -ge 6) {
            $Text = $Text.Replace($value, "***")
        }
    }
    return [regex]::Replace($Text, '(://[^:/@\s]+):[^@\s/]+@', '$1:***@')
}

function Write-LogHeader {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    $logLines.Add("=" * 60)
    $logLines.Add(" EduEdu+ - Log de suporte")
    $logLines.Add("=" * 60)
    Write-LogItem "Gerado em" $generatedAt.ToString("dd/MM/yyyy HH:mm:ss")
    Write-LogItem "Versao do EduEdu+ (.env)" $(if ($envValues["APP_VERSION"]) { $envValues["APP_VERSION"] } else { "nao encontrada" })
    Write-LogItem "Windows" $(if ($os) { "$($os.Caption) ($($os.Version))" } else { "nao identificado" })
    Write-LogItem "Computador" $env:COMPUTERNAME
    Write-LogItem "Pasta da instalacao" $projectRoot
    Write-LogItem "Arquivo .env" $(if (Test-Path $envPath) { "Encontrado" } else { "Nao encontrado" })
    Write-LogItem "Executado como administrador" $(if ($isAdmin) { "Sim" } else { "Nao" })
}

function Save-Log {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $path = Join-Path $logDir ("log_{0}.txt" -f $generatedAt.ToString("yyyy-MM-dd_HH-mm-ss"))
    $content = Protect-Secrets (($logLines -join "`r`n") + "`r`n")

    # UTF-8 com BOM para o Bloco de Notas mostrar os acentos da saida dos comandos
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($true)))

    return [pscustomobject]@{ Path = $path; Content = $content }
}

# ----------------- Comandos externos -----------------

# Roda um executavel com tempo limite e devolve a saida. Um Docker travado
# (ex.: ainda iniciando) nao pode deixar o script parado para sempre.
#   Found       - $false se o executavel nao existe
#   TimedOut    - $true se o tempo limite estourou (o processo e encerrado)
#   ExitCode, Output (stdout) e ErrorOutput (stderr)
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSec = 30,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
    )

    $result = [pscustomobject]@{ Found = $false; TimedOut = $false; ExitCode = $null; Output = ""; ErrorOutput = "" }

    $command = Get-Command $FilePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return $result }
    $result.Found = $true

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName               = $command.Source
    $psi.Arguments              = ($Arguments | ForEach-Object { if ($_ -match '[\s"|&<>^]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join " "
    $psi.WorkingDirectory       = $projectRoot
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.StandardOutputEncoding = $Encoding
    $psi.StandardErrorEncoding  = $Encoding

    $process = [System.Diagnostics.Process]::Start($psi)
    # Le os dois fluxos ao mesmo tempo: lendo um de cada vez, o processo trava
    # quando o buffer do outro enche
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()

    if (-not $process.WaitForExit($TimeoutSec * 1000)) {
        try { $process.Kill() } catch { }
        $result.TimedOut = $true
        return $result
    }

    $result.ExitCode    = $process.ExitCode
    $result.Output      = $stdout.Result.Trim()
    $result.ErrorOutput = $stderr.Result.Trim()
    return $result
}

# ----------------- Rede -----------------

# Placas de rede fisicas, conectadas e com gateway padrao (as que saem para a
# internet), da principal (menor metrica, a que o Windows usa) para as demais.
# -Physical descarta as placas virtuais (Hyper-V/WSL, VPN, Hotspot Movel) e a
# rota padrao descarta placas fisicas sem internet, como o adaptador de
# loopback instalado por modulos de seguranca de bancos.
function Get-InternetAdapters {
    $routes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -ne "0.0.0.0" })

    $adapters = foreach ($adapter in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Up" })) {
        $route = $routes | Where-Object { $_.ifIndex -eq $adapter.ifIndex } | Sort-Object RouteMetric | Select-Object -First 1
        if (-not $route) { continue }

        $interface = Get-NetIPInterface -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

        [pscustomobject]@{
            Name        = $adapter.Name
            Description = $adapter.InterfaceDescription
            Medium      = $adapter.NdisPhysicalMedium
            Metric      = [int]$route.RouteMetric + [int]$interface.InterfaceMetric
            IPv4        = @(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                            Where-Object { $_.AddressState -eq "Preferred" } |
                            Select-Object -ExpandProperty IPAddress)
        }
    }

    @($adapters | Sort-Object Metric)
}

# ----------------- Main -----------------

function Main {
    Write-Host ""
    Write-Color "------- EduEdu+ - Coleta de dados para suporte -------" Cyan

    Write-LogHeader

    $checks = @(Get-ChildItem -Path $checksDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($checks.Count -eq 0) {
        Write-LogItem "Verificacoes" "nenhuma encontrada em $checksDir"
    }

    foreach ($check in $checks) {
        try {
            # Escopo filho: variaveis e funcoes de uma verificacao nao vazam para a proxima
            & { . $check.FullName }
        } catch {
            Write-LogItem "ERRO na verificacao $($check.Name)" $_.Exception.Message
            Write-Color "[ ERRO ] $($check.Name): $($_.Exception.Message)" Red
        }
    }

    $log = Save-Log

    $copied = $false
    if (-not $Silencioso) {
        try {
            Set-Clipboard -Value $log.Content
            $copied = $true
        } catch { }
    }

    Write-Host ""
    Write-Color "------------------------------------------------------" Cyan
    Write-Color "[ OK ] Log gerado em:" Green
    Write-Color "       $($log.Path)" White
    Write-Host ""
    Write-Color "Envie esse arquivo para o suporte do EduEdu+." White
    if ($copied) {
        Write-Color "O conteudo tambem foi copiado: e so colar (Ctrl+V) na conversa com o suporte." White
    }

    if (-not $Silencioso) {
        # Abre a pasta com o arquivo ja selecionado, pronto para anexar
        Start-Process explorer.exe -ArgumentList "/select,`"$($log.Path)`""
    }
}

Main

if (-not $Silencioso) {
    Write-Host ""
    Write-Host "Pressione Enter para fechar..."
    Read-Host | Out-Null
}
