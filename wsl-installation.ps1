# install-wsl.ps1
Write-Host "=== Verificando WSL ===" -ForegroundColor Cyan

$needsReboot = $false

# Verifica se o comando wsl existe
$wslCommand = Get-Command wsl.exe -ErrorAction SilentlyContinue

if (-not $wslCommand) {
    Write-Host "WSL não está instalado. Iniciando instalação..." -ForegroundColor Yellow
    try {
        Start-Process "wsl.exe" -ArgumentList "--install -d Ubuntu" -Verb RunAs -Wait
        Write-Host "WSL e Ubuntu instalados com sucesso." -ForegroundColor Green
        $needsReboot = $true
    }
    catch {
        Write-Host "Erro ao instalar WSL. Verifique se o sistema suporta WSL2 (Windows 10 2004+ ou Windows 11)." -ForegroundColor Red
    }
}
else {
    try {
        # Verifica se há distribuições ou se o comando retorna uma mensagem de ajuda
        $hasHelpMessageInsteadOfDist = (wsl -l -v | ForEach-Object { $_ -split "\s" }) -contains '--install'

        if ($hasHelpMessageInsteadOfDist) {
            Write-Host "Nenhuma distribuição WSL instalada. Instalando Ubuntu..." -ForegroundColor Yellow
            Start-Process "wsl.exe" -ArgumentList "--install -d Ubuntu" -Verb RunAs -Wait
            Write-Host "Ubuntu instalado com sucesso." -ForegroundColor Green
        }
        else {
            Write-Host "Ubuntu ja instalado no WSL." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Erro ao verificar distribuições WSL." -ForegroundColor Red
    }
}

# Avisa da reinicialização
if ($needsReboot) {
    Write-Host "É necessário reiniciar o computador para concluir a instalação do WSL." -ForegroundColor Yellow
} 

# Mantém a janela aberta no final
Write-Host "`nPressione qualquer tecla para sair..."
[void][System.Console]::ReadKey($true)
