# Pré-requisitos

Os seguintes itens precisam ser atendidos antes de iniciar a instalação:
- Instalação do GIT
    - [Windows](https://git-scm.com/download/win)
    - [Linux](https://git-scm.com/download/linux)<br><br>

- Instalação do Docker
    - Windows
        - [Instalação WSL](https://learn.microsoft.com/pt-br/windows/wsl/install)
        - [Instalação Docker no Windows](https://docs.docker.com/desktop/install/windows-install/)
    - Linux
        - [Instalação Docker no Linux](https://docs.docker.com/engine/install/#server) <br><br>
- [Instalação do CURL](https://curl.se/download.html)

- Execução do script de instalação:
    - Windows: Deve ser executado imprescindivelmente no GIT BASH.
    - Linux: Deve ser executado imprescindivelmente no terminal.

- Nível de permissão:
    A instalação deve ser feita imprescindivelmente com um usuário administrador da máquina.
<br>



<h3 style="color:red;">ATENÇÃO</h3>
Para o funcionamento do mecanismo de e-mail, será necessário uma credencial SMTP válida.<br>
<b><span style="color:red;">
Esse item é obrigatório para que os usuários cadastrados recebam o e-mail de confirmação de conta.
</span></b>

---

# Instalação

### 1. Acesse o diretório raíz do pacote de instalação
- Se estiver no Windows, faça isso no GIT BASH
- Se estiver no Linux, faça isso no terminal

### 2. Execução do script de instalação
Execute o comando abaixo para rodar o script de instalação:
```
./startup.sh
```

### 3. Informando o IP ou alias da máquina na rede interna
Ao rodar o script de instalação, será solicitado o IP ou alias da máquina na rede interna.
Para obter o IP da máquina, siga os passos abaixo:

- Windows
    - Clique no ícone Iniciar e selecione Configurações.
    - Clique no ícone Rede e Internet.
    - Para visualizar o endereço IP de uma conexão com fio, selecione Ethernet no painel de menu à esquerda e escolha sua conexão de rede; seu endereço IP aparecerá ao lado de "Endereço IPv4".
    - Para visualizar o endereço IP de uma conexão sem fio, selecione Wi-Fi no painel de menu à esquerda e clique em Opções Avançadas; seu endereço IP aparecerá ao lado de "Endereço IPv4".

- Linux
    // TODO...

---

### 4. Finalização da Instalação

Após finalizada a execução do script de instalação, será exibido um resultado similar ao da imagem abaixo:

![installation-done](./docs/installation-done.png)

O Portal Admin poderá ser acessado no endereço:
<b>http://<IP da máquina informado>:8080</b>

O Portal Aluno poderá ser acessado no endereço:
<b>http://<IP da máquina informado>:9090</b>

---

# Considerações

### Liberação de Portas

Para que os Portais Admin e Aluno sejam acessados na rede interna, será necessário efetuar a liberação das seguintes portas:
- 8080 (Porta da aplicação Portal Admin)
- 9090 (Porta da aplicação Portal Aluno)
- 3000 (Porta da API)

Para mais detalhes sobre liberação de portas, acesse os links abaixo:

- Windows: [Criar uma regra de porta de entrada
](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)

- Linux: // TODO...
