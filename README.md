<h1 align="center">EduEdu+ Escola Setup</h1>

<p align="center">
  Pacote de instalação e orquestração da plataforma EduEdu+, um sistema de avaliação e acompanhamento de alfabetização para escolas brasileiras.
</p>

<p align="center">
  <a href="#sobre-o-projeto">Sobre</a> &bull;
  <a href="#tecnologias">Tecnologias</a> &bull;
  <a href="#arquitetura">Arquitetura</a> &bull;
  <a href="#pré-requisitos">Pré-requisitos</a> &bull;
  <a href="#instalação">Instalação</a> &bull;
  <a href="#estrutura-do-projeto">Estrutura</a> &bull;
  <a href="#variáveis-de-ambiente">Ambiente</a> &bull;
  <a href="#comandos-úteis">Comandos</a> &bull;
  <a href="#contribuindo">Contribuindo</a> &bull;
  <a href="#licença">Licença</a>
</p>

---

## Sobre o Projeto

O **EduEdu+ Escola Setup** é o pacote de implantação local da plataforma educacional EduEdu+. Ele automatiza toda a instalação e configuração dos serviços necessários para rodar a plataforma em uma rede escolar, incluindo backend, portais web, bancos de dados e cache.

O instalador detecta automaticamente o IP da máquina, instala dependências do sistema operacional (Docker, WSL, WinGet), configura variáveis de ambiente e valida que todos os serviços estão respondendo corretamente.

### Funcionalidades Principais

- **Instalação automatizada** &mdash; Scripts que instalam e configuram todas as dependências necessárias
- **Detecção automática de rede** &mdash; Identifica o IP local da máquina para acesso na rede escolar
- **Suporte multiplataforma** &mdash; Instaladores dedicados para Windows e Linux
- **Orquestração de serviços** &mdash; Gerenciamento de 7 containers Docker via Docker Compose
- **Validação de saúde** &mdash; Verificação automática de que todos os serviços estão respondendo
- **Instalação e atualização** &mdash; Suporte para instalação limpa e atualização de versão

### Repositórios Relacionados

| Repositório                                                                      | Descrição                                          |
| -------------------------------------------------------------------------------- | -------------------------------------------------- |
| [eduedu-escola-backend](https://github.com/instituto-abcd/eduedu-escola-backend) | API backend (NestJS + Prisma + MongoDB)            |
| [eduedu-escola-admin](https://github.com/instituto-abcd/eduedu-escola-admin)     | Interface administrativa (diretores e professores) |
| [eduedu-escola-aluno](https://github.com/instituto-abcd/eduedu-escola-aluno)     | Interface do aluno                                 |

---

## Tecnologias

| Categoria           | Tecnologia                                                   |
| ------------------- | ------------------------------------------------------------ |
| Orquestração        | [Docker](https://www.docker.com/) + Docker Compose           |
| Banco Relacional    | [PostgreSQL](https://www.postgresql.org/) 17.6               |
| Banco de Documentos | [MongoDB](https://www.mongodb.com/) 8.0                      |
| Cache               | [Redis](https://redis.io/)                                   |
| Fila de Mensagens   | [CloudAMQP](https://www.cloudamqp.com/) (RabbitMQ hospedado) |
| Scripts Windows     | PowerShell                                                   |
| Scripts Linux       | Bash                                                         |
| Registro de Imagens | Google Cloud Artifact Registry                               |

---

## Arquitetura

O sistema é composto por 7 containers Docker orquestrados via Docker Compose:

```
┌─────────────┐   ┌─────────────┐
│  PostgreSQL  │   │   MongoDB   │
│  :5432       │   │   :27017    │
└──────┬───────┘   └──────┬──────┘
       │                  │
       └────────┬─────────┘
                │
       ┌────────▼────────┐
       │    Migration     │    (npx prisma migrate deploy && seed)
       └────────┬────────┘
                │
       ┌────────▼────────┐     ┌─────────────┐
       │    Backend API   │     │    Redis     │
       │    :3000         │     │    :6379     │
       └──┬───────────┬──┘     └─────────────┘
          │           │
   ┌──────▼──┐   ┌───▼──────┐
   │  Admin   │   │  Aluno   │
   │  :8080   │   │  :9090   │
   └─────────┘   └──────────┘
```

### Serviços

| Serviço     | Porta | Descrição                                             |
| ----------- | ----- | ----------------------------------------------------- |
| `backend`   | 3000  | API NestJS (Swagger disponível em `/swagger`)         |
| `admin`     | 8080  | Portal administrativo (diretores e professores)       |
| `aluno`     | 9090  | Portal do aluno                                       |
| `migration` | —     | Executa migrações Prisma e seed, depois finaliza      |
| `postgres`  | 5432  | Banco de dados relacional                             |
| `mongo`     | 27017 | Banco de dados de documentos (avaliações e execuções) |
| `redis`     | 6379  | Cache e filas de processamento assíncrono             |

### Arquivos de Composição

- **`docker-compose.yml`** &mdash; Windows (Docker Desktop). PostgreSQL 17.6, MongoDB 8.0, volume nomeado `pgdata`
- **`docker-compose.linux.yml`** &mdash; Linux. PostgreSQL `latest`, MongoDB 4.4, volume mapeado

As imagens são pré-compiladas e hospedadas no Google Cloud Artifact Registry:

```
southamerica-east1-docker.pkg.dev/eduedu-plus-open-source-prd/eduedu-plus-setup/
├── eduedu-plus-backend:<versão>
├── eduedu-plus-admin:<versão>
└── eduedu-plus-aluno:<versão>
```

---

## Pré-requisitos

### Windows

- Windows 10 ou 11 64-bit (versão 22H2 ou superior)
- Processador com suporte a virtualização (Intel Core i3+ 4ª geração, AMD Ryzen, etc.)
- Mínimo de 4GB de RAM e 8GB de armazenamento disponível
- Privilégios de administrador
- [Virtualização de hardware habilitada na BIOS/UEFI](https://learn.microsoft.com/pt-br/answers/questions/4039785/como-fa-o-para-ativar-virtualiza-o-de-hardware)

> WinGet, WSL 2 e Docker Desktop são instalados automaticamente pelo script caso não estejam presentes.

### Linux

- Superusuário (sudo)
- `wget` instalado (instalado automaticamente se ausente)
- Docker e Docker Compose (instalados automaticamente se ausentes)

### Todos os Ambientes

- Credencial SMTP válida para o sistema de e-mail (confirmação de conta)
- Acesso à internet para baixar imagens Docker do Artifact Registry

---

## Instalação

### Windows

Para instruções detalhadas com capturas de tela, consulte a [documentação de instalação para Windows](docs/Windows.md).

**Resumo:**

1. Baixe e extraia o projeto para a área de trabalho
2. Clique duas vezes em `Instalador-Windows.cmd`
3. Se solicitado, permita a execução como administrador
4. Siga as instruções na tela para instalar dependências (WinGet, WSL, Docker)
5. Aguarde a instalação e validação dos serviços

> **Importante:** O script pode precisar ser executado mais de uma vez caso ferramentas precisem ser instaladas (algumas requerem reinicialização).

### Linux

1. Dê permissões de execução ao script:

```bash
chmod +x startup-linux.sh
```

2. Execute o instalador:

```bash
sudo bash startup-linux.sh
```

### Conclusão da Instalação

Após a conclusão do script, você verá um resultado semelhante à imagem abaixo:

![installation-done](./docs/installation-done.png)

**Portal do Administrador:**

- Acesse em: http://<IP da máquina informado>:8080

**Portal do Aluno:**

- Acesse em: http://<IP da máquina informado>:9090

---

## Dicas Finais

**Liberação de Portas**

Para acessar os Portais do Administrador e do Aluno na rede interna, certifique-se de liberar as seguintes portas:

- 8080 (Portal do Administrador)
- 9090 (Portal do Aluno)
- 3000 (API)

Para mais detalhes sobre como liberar portas, consulte os links abaixo:

- **Windows**: [Criar uma regra de porta de entrada](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)

## Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do repositório
2. Crie uma branch para sua feature (`git checkout -b feature/minha-feature`)
3. Faça commit das alterações (`git commit -m 'feat: descrição da feature'`)
4. Faça push para a branch (`git push origin feature/minha-feature`)
5. Abra um Pull Request

## Licença

Este projeto é mantido pelo [Instituto ABCD](https://www.institutoabcd.org.br/).

Consulte o arquivo [LICENSE](LICENSE.md) para mais detalhes.
