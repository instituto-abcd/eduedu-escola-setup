# Pré-requisitos

Antes de iniciar a instalação, certifique-se de atender aos seguintes requisitos:

## Para Windows:

### GIT
- [Download do GIT para Windows](https://git-scm.com/download/win)

### Docker
1. [Instalação WSL](https://learn.microsoft.com/pt-br/windows/wsl/install)
2. [Instalação Docker no Windows](https://docs.docker.com/desktop/install/windows-install/)

### CURL
- [Download do CURL](https://curl.se/download.html)

## Para Linux:

### GIT
- [Download do GIT para Linux](https://git-scm.com/download/linux)

### Docker
- [Instalação Docker no Linux](https://docs.docker.com/engine/install/#server)

### CURL
- [Download do CURL](https://curl.se/download.html)

**Execução do script de instalação:**
- **Windows**: Utilize o GIT BASH.
- **Linux**: Execute no terminal.

**Nível de permissão:**
A instalação requer privilégios de administrador.

## ATENÇÃO
Para o correto funcionamento do sistema de e-mail, é essencial uma credencial SMTP válida. Este requisito é obrigatório para que os usuários recebam o e-mail de confirmação da conta.

---

# Instalação no Windows

**1. Acesse o diretório raíz do pacote de instalação:**
- Utilize o GIT BASH.

**2. Execute o script de instalação:**
```bash
./startup.sh
```

**3. Informando o IP ou alias da máquina na rede interna:**

Após a execução do script, insira o IP ou alias da máquina seguindo as instruções abaixo.

### Windows:
1. Clique em Iniciar e selecione Configurações.
2. Escolha Rede e Internet.
3. Para visualizar o endereço IP, clique em "Ethernet" para conexões com fio ou "Wi-Fi" para conexões sem fio. O endereço IPv4 estará visível.

---

# Instalação no Linux

**1. Acesse o diretório raíz do pacote de instalação:**
- Utilize o terminal.

**2. Execute o script de instalação:**
```bash
./startup.sh
```

**3. Informando o IP ou alias da máquina na rede interna:**

Após a execução do script, insira o IP ou alias da máquina seguindo as instruções abaixo.

### Linux:
1. Abra o terminal.
2. Execute o seguinte comando:
```bash
sudo ./startup-linux.sh
```

---

**4. Finalização da Instalação**

Após a conclusão do script, você verá um resultado semelhante à imagem abaixo:

![installation-done](./docs/installation-done.png)

**Portal Admin:**
- Acesse em: http://<IP da máquina informado>:8080

**Portal Aluno:**
- Acesse em: http://<IP da máquina informado>:9090

---

# Considerações

**Liberação de Portas**

Para acessar os Portais Admin e Aluno na rede interna, libere as seguintes portas:
- 8080 (Portal Admin)
- 9090 (Portal Aluno)
- 3000 (API)

Para mais detalhes sobre liberação de portas, consulte os links abaixo:

- **Windows**: [Criar uma regra de porta de entrada](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)
