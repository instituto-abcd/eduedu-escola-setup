# Verificacao: status do WSL e do Docker no momento da coleta
# ----------------------------------------------------------------------
# O Docker Desktop roda sobre o WSL 2 (distribuicao docker-desktop). Com o WSL
# parado ou o Docker Engine sem responder, os containers do EduEdu+ nao sobem.

function Get-ServiceStatus($Name) {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) { return $null }

    switch ($service.Status.ToString()) {
        "Running" { "Em execucao" }
        "Stopped" { "Parado" }
        default   { $service.Status.ToString() }
    }
}

# O wsl.exe escreve em UTF-16 quando a saida e redirecionada, a menos que
# WSL_UTF8=1 esteja definido. Sem a variavel a codificacao e sempre a mesma.
Remove-Item Env:WSL_UTF8 -ErrorAction SilentlyContinue

function Invoke-Wsl([string[]]$Arguments) {
    Invoke-Native "wsl.exe" $Arguments -Encoding ([System.Text.Encoding]::Unicode)
}

# ----------------- WSL -----------------

Write-LogSection "WSL"

$wslVersion = Invoke-Wsl @("--version")
$distros    = Invoke-Wsl @("--list", "--quiet")
$running    = Invoke-Wsl @("--list", "--running", "--quiet")

if (-not $wslVersion.Found) {
    Write-LogItem "WSL instalado" "Nao (wsl.exe nao encontrado)"
} elseif ($wslVersion.ExitCode -ne 0 -and $distros.ExitCode -ne 0) {
    Write-LogItem "WSL instalado" "Nao"
    $detail = ConvertTo-Lines "$($distros.Output)`n$($distros.ErrorOutput)" | Select-Object -First 1
    if ($detail) { Write-LogItem "Detalhe" $detail }
} else {
    $version = if ($wslVersion.ExitCode -eq 0 -and $wslVersion.Output -match '(\d+\.\d+\.\d+(\.\d+)?)') { $matches[1] } else { "nao identificada" }
    Write-LogItem "WSL instalado" "Sim (versao $version)"

    # --list --running sai com erro quando nenhuma distribuicao esta rodando
    $distroNames  = if ($distros.ExitCode -eq 0) { ConvertTo-Lines $distros.Output } else { @() }
    $runningNames = if ($running.ExitCode -eq 0) { ConvertTo-Lines $running.Output } else { @() }

    Write-LogItem "Status do WSL" $(if ($runningNames.Count -gt 0) { "Em execucao" } else { "Parado" })

    if ($distroNames.Count -eq 0) {
        Write-LogItem "Distribuicoes" "nenhuma instalada"
    } else {
        $list = $distroNames | ForEach-Object {
            if ($runningNames -contains $_) { "$_ (em execucao)" } else { "$_ (parada)" }
        }
        Write-LogItem "Distribuicoes" ($list -join ", ")
    }
}

foreach ($serviceName in @("WSLService", "LxssManager")) {
    $status = Get-ServiceStatus $serviceName
    if ($status) { Write-LogItem "Servico $serviceName" $status }
}

# ----------------- Docker -----------------

Write-LogSection "Docker"

$client = Invoke-Native "docker" @("--version")

if (-not $client.Found) {
    Write-LogItem "Docker instalado" "Nao (comando docker nao encontrado)"
} else {
    $clientVersion = if ($client.Output -match '(\d+\.\d+\.\d+)') { $matches[1] } else { "nao identificada" }
    Write-LogItem "Docker instalado" "Sim (versao $clientVersion)"

    $desktop = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    Write-LogItem "Docker Desktop (aplicativo)" $(if ($desktop) { "Aberto" } else { "Fechado" })

    $serviceStatus = Get-ServiceStatus "com.docker.service"
    if ($serviceStatus) { Write-LogItem "Servico com.docker.service" $serviceStatus }

    $engine = Invoke-Native "docker" @("version", "--format", "{{.Server.Version}}|{{.Server.Os}}") -TimeoutSec 30

    if ($engine.TimedOut) {
        Write-LogItem "Docker Engine" "Sem resposta em 30s (iniciando ou travado)"
    } elseif ($engine.ExitCode -eq 0) {
        $server = $engine.Output.Split("|")
        Write-LogItem "Docker Engine" "Em execucao (versao $($server[0]))"
        # Em modo "containers Windows" as imagens Linux do EduEdu+ nao rodam
        Write-LogItem "Tipo de container" $(if ($server[1] -eq "linux") { "Linux" } else { "$($server[1]) (o EduEdu+ precisa de containers Linux)" })
    } else {
        Write-LogItem "Docker Engine" "Parado ou sem acesso"
        $detail = ConvertTo-Lines "$($engine.ErrorOutput)`n$($engine.Output)" | Select-Object -First 1
        if ($detail) { Write-LogItem "Detalhe" $detail }
    }

    $compose = Invoke-Native "docker" @("compose", "version", "--short")
    Write-LogItem "Docker Compose" $(if ($compose.ExitCode -eq 0) { $compose.Output } else { "nao encontrado" })
}
