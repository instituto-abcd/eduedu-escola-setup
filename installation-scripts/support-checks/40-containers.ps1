# Verificacao: status e logs dos containers do EduEdu+
# ----------------------------------------------------------------------
# Lista os servicos do docker-compose.yml com o estado do container de cada
# um e grava as ultimas linhas do log de cada container. O docker compose roda
# na pasta do projeto, entao enxerga o mesmo projeto criado pelo instalador.

$logTail = 100

Write-LogSection "Containers do EduEdu+"

$services = Invoke-Native "docker" @("compose", "config", "--services")

if (-not $services.Found) {
    Write-LogItem "Containers" "Indisponivel: Docker nao encontrado"
    return
}

if ($services.ExitCode -ne 0) {
    Write-LogItem "Containers" "Indisponivel: erro ao ler o docker-compose.yml"
    Write-LogText $services.ErrorOutput
    return
}

$ps = Invoke-Native "docker" @("compose", "ps", "--all", "--format", "{{.Service}}|{{.Name}}|{{.State}}|{{.Status}}|{{.Image}}") -TimeoutSec 30

if ($ps.TimedOut) {
    Write-LogItem "Containers" "Indisponivel: o Docker nao respondeu em 30s"
    return
}

if ($ps.ExitCode -ne 0) {
    Write-LogItem "Containers" "Indisponivel: erro ao listar os containers"
    Write-LogText $ps.ErrorOutput
    return
}

# Servico -> campos do container (servico, nome, estado, status, imagem)
$containers = @{}
foreach ($line in ConvertTo-Lines $ps.Output) {
    $fields = $line.Split("|")
    if ($fields.Count -ge 5) { $containers[$fields[0]] = $fields }
}

$serviceNames = ConvertTo-Lines $services.Output

# Tabela com uma linha por servico; servico sem container aparece como "nao criado"
$rows = @(, @("SERVICO", "CONTAINER", "ESTADO", "STATUS", "IMAGEM"))
foreach ($service in $serviceNames) {
    if ($containers.ContainsKey($service)) {
        $rows += , $containers[$service]
    } else {
        $rows += , @($service, "-", "nao criado", "-", "-")
    }
}

# Colunas na largura do maior valor (o nome do container depende da pasta da instalacao)
$widths = foreach ($column in 0..3) {
    ($rows | ForEach-Object { $_[$column].Length } | Measure-Object -Maximum).Maximum
}
Write-LogText ($rows | ForEach-Object {
    $fields = $_
    ((0..3 | ForEach-Object { $fields[$_].PadRight($widths[$_]) }) + $fields[4]) -join "  "
})

foreach ($service in $serviceNames) {
    if (-not $containers.ContainsKey($service)) { continue }

    $name = $containers[$service][1]
    Write-LogSection "Log do container $name (ultimas $logTail linhas)"

    # O cmd junta stdout e stderr do container na ordem em que foram escritos
    $logs = Invoke-Native "cmd.exe" @("/d", "/c", "docker logs --timestamps --tail $logTail $name 2>&1") -TimeoutSec 60

    if ($logs.TimedOut) {
        Write-LogText "(o Docker nao respondeu em 60s)"
    } else {
        Write-LogText $logs.Output
    }
}
