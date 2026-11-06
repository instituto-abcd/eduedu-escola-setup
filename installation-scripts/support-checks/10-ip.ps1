# Verificacao: IP atual x IP da instalacao
# ----------------------------------------------------------------------
# O IP da instalacao e o APP_ADDRESS que o instalador grava no .env. Os
# portais admin e aluno sao buildados com esse IP: se ele nao estiver mais em
# uma placa conectada a internet, os alunos nao conseguem acessar o EduEdu+.
# O log registra so se o IP mudou, sem os IPs.

function Test-IPv4Address($Value) {
    $parsed = $null
    return ("$Value" -match '^\d{1,3}(\.\d{1,3}){3}$') -and [System.Net.IPAddress]::TryParse($Value, [ref]$parsed)
}

# Compara o IP da instalacao com os IPs atuais das placas conectadas a internet.
#   Changed - $true (mudou), $false (nao mudou) ou $null (nao foi possivel comparar)
#   Reason  - explicacao quando mudou ou quando nao foi possivel comparar
function Compare-InstallationIP {
    $installationIP = $envValues["APP_ADDRESS"]

    # 127.0.0.1 e o valor que vem no .env do repositorio, antes da instalacao gravar o IP
    if (-not (Test-IPv4Address $installationIP) -or $installationIP.StartsWith("127.")) {
        return [pscustomobject]@{
            Changed = $null
            Reason  = "o .env nao tem o IP da instalacao (APP_ADDRESS vazio ou com o valor padrao)"
        }
    }

    $currentIPs = @(Get-InternetAdapters | ForEach-Object { $_.IPv4 })
    if ($currentIPs.Count -eq 0) {
        return [pscustomobject]@{
            Changed = $null
            Reason  = "nenhuma placa de rede conectada a internet"
        }
    }

    # Com Wi-Fi e cabo ligados ao mesmo tempo, basta o IP estar em uma das placas
    if ($currentIPs -contains $installationIP) {
        return [pscustomobject]@{ Changed = $false; Reason = "" }
    }

    return [pscustomobject]@{
        Changed = $true
        Reason  = "o IP gravado na instalacao nao esta em nenhuma placa conectada a internet (o IP mudou ou a instalacao gravou o IP de uma placa virtual)"
    }
}

Write-LogSection "Endereco IP"

$comparison = Compare-InstallationIP
$changed = if ($comparison.Changed -eq $true) { "Sim" } elseif ($comparison.Changed -eq $false) { "Nao" } else { "Indeterminado" }

Write-LogItem "IP alterado desde a instalacao" $changed
if ($comparison.Reason) {
    Write-LogItem "Motivo" $comparison.Reason
}
