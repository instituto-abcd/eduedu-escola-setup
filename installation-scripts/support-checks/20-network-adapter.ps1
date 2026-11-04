# Verificacao: tipo do adaptador de conexao com a internet
# ----------------------------------------------------------------------
# Indica se o computador sai para a internet pelo Wi-Fi ou pelo cabo. O tipo
# vem do meio fisico da placa (NdisPhysicalMedium), e nao do nome da conexao,
# que muda com o idioma do Windows e pode ser renomeado.

function Get-AdapterType($Medium) {
    switch ($Medium) {
        9       { "Wi-Fi" }             # Native 802.11
        14      { "Ethernet (cabo)" }   # 802.3
        8       { "Rede movel" }        # Wireless WAN
        default { "Outro (meio fisico $Medium)" }
    }
}

function Format-Adapter($Adapter) {
    "{0} - {1} ({2})" -f (Get-AdapterType $Adapter.Medium), $Adapter.Name, $Adapter.Description
}

Write-LogSection "Adaptador de conexao"

$adapters = @(Get-InternetAdapters)

if ($adapters.Count -eq 0) {
    Write-LogItem "Conectado a internet por" "Nenhuma placa conectada a internet"
} else {
    $types = @($adapters | ForEach-Object { Get-AdapterType $_.Medium } | Select-Object -Unique)
    Write-LogItem "Conectado a internet por" ($types -join " e ")

    # A primeira e a de menor metrica, a que o Windows usa para sair para a internet
    Write-LogItem "Placa principal" (Format-Adapter $adapters[0])
    foreach ($adapter in @($adapters | Select-Object -Skip 1)) {
        Write-LogItem "Outra placa conectada" (Format-Adapter $adapter)
    }
}
