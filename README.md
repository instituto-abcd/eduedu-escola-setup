# Guia de Pré-requisitos e Instalação

## Pré-requisitos

Antes de iniciar a instalação, certifique-se de atender aos seguintes requisitos:

### Para Windows:

#### GIT
- [Download do GIT para Windows](https://git-scm.com/download/win)

#### Docker
1. [Instalação WSL](https://learn.microsoft.com/pt-br/windows/wsl/install)
2. [Instalação Docker no Windows](https://docs.docker.com/desktop/install/windows-install/)

#### CURL
- [Download do CURL](https://curl.se/download.html)

### Para Linux:

#### GIT
- [Download do GIT para Linux](https://git-scm.com/download/linux)

#### Docker
- [Instalação Docker no Linux](https://docs.docker.com/engine/install/#server)

#### CURL
- [Download do CURL](https://curl.se/download.html)

**Execução do script de instalação:**
- **Windows**: Utilize o GIT BASH.
- **Linux**: Execute no terminal.

**Nível de permissão:**
A instalação requer privilégios de administrador.

## ATENÇÃO
Para o correto funcionamento do sistema de e-mail, é essencial uma credencial SMTP válida. Este requisito é obrigatório para que os usuários recebam o e-mail de confirmação da conta.

---

## Guia de Instalação

### Para Windows:

1. **Localizando seu Endereço IP:**
   - Clique em "Iniciar" e acesse "Configurações".
   - Selecione "Rede e Internet".
   - Encontre o endereço IP clicando em "Ethernet" para conexões com fio ou "Wi-Fi" para conexões sem fio. O endereço IPv4 estará visível.

2. **Acessando o Diretório Raíz:**
   - Utilize o terminal.

3. **Executando o Script de Instalação:**
   ```bash
   ./startup.sh
   ```

4. **Durante a Execução:**
   - Durante a instalação, será solicitado seu endereço IP.
   - Informe o endereço IPv4 obtido na etapa 1.

### Para Linux:

1. **Abrindo o Terminal:**
   - Execute o seguinte comando:
     ```bash
     sudo ./startup-linux.sh
     ```

---

**Finalização da Instalação**

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
