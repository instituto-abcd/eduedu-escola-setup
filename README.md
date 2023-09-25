# Pré-requisitos

Os seguintes itens precisam ser atendidos antes de iniciar a instalação:
- Instalação do GIT <br><br>

- Instalação do Docker
    - Windows
        - Links: // TODO
    - Linux
        - Links: // TODO <br><br>
- Instalação do CURL: // TODO <br><br>
- Prompt de Comando
    - Windows:
        - Instalação do GIT BASH
    - Linux
        - Terminal <br><br>
- Credenciais SMTP válidas para funcionamento do mecanismo de e-mail.
<b>ATENÇÃO:</b> Esse item é obrigatório para que os usuários cadastrados recebam o e-mail de confirmação de conta.

# Instalação

### 1. Clone do repositório de instalação
Efetue o clone do repositório através do comando abaixo:
```
git clone https://github.com/instituto-abcd/eduedu-escola-setup.git
```

### 2. Acesso ao diretório do repositório
Execute o comando abaixo para entrar no diretório:
```
cd eduedu-escola-setup
```

### 3. Execução do script de instalação
Execute o comando abaixo para rodar o script de instalação:
```
./startup.sh
```

### 4. Informando o IP ou alias da máquina na rede interna
Ao rodar o script de instalação, será solicitado o IP ou alias da máquina na rede interna.
Para obter o IP da máquina, siga os passos abaixo:

- Windows
    - Clique no ícone Iniciar e selecione Configurações.
    - Clique no ícone Rede e Internet.
    - Para visualizar o endereço IP de uma conexão com fio, selecione Ethernet no painel de menu à esquerda e escolha sua conexão de rede; seu endereço IP aparecerá ao lado de "Endereço IPv4".
    - Para visualizar o endereço IP de uma conexão sem fio, selecione Wi-Fi no painel de menu à esquerda e clique em Opções Avançadas; seu endereço IP aparecerá ao lado de "Endereço IPv4".

- Linux
    // TODO...

### 5. Finalização da Instalação

Após finalizada a execução do script de instalação, a janela do GIT BASH exibirá um resultado similar ao da imagem abaixo:

![installation-done](./docs/installation-done.png)

O Portal Admin poderá ser acessado no endereço:
http://<IP da máquina informado>:8080

O Portal Aluno poderá ser acessado no endereço:
http://<IP da máquina informado>:9090

# Considerações

### Liberação de Portas

Para que os Portais Admin e Aluno sejam acessados na rede interna, será necessário efetuar a liberação das seguintes portas:
- 8080 (Porta da aplicação Portal Admin)
- 9090 (Porta da aplicação Portal Aluno)
- 3000 (Porta da API)

Para mais detalhes sobre liberação de portas, veja os links abaixo:

- Windows: [Criar uma regra de porta de entrada
](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)

- Linux: // TODO...

### Reiniciar os Serviços
// TODO...

 
