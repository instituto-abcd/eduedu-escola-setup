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

## 3. Informando o IP ou alias da máquina na rede interna

Após a execução do script de instalação, será solicitado o IP ou alias da máquina na rede interna. Para obter o IP da máquina, siga as instruções abaixo, conforme o sistema operacional.

### Windows:

1. Clique em Iniciar e selecione Configurações.
2. Selecione Rede e Internet.
3. Para visualizar o endereço IP, clique em "Ethernet" para conexões com fio ou "Wi-Fi" para conexões sem fio no painel à esquerda. O endereço IPv4 estará visível.

# Inicialização no Linux

Para iniciar o processo no ambiente Linux, siga as instruções abaixo:

1. Abra o terminal.
2. Insira o seguinte comando:

```
sudo ./startup-linux.sh
```


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
