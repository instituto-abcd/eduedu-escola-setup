# Guia de Instalação EduEdu

## Antes de Começar

Antes de iniciar a instalação, certifique-se de ter os seguintes itens prontos:

### Para Usuários do Windows:

#### GIT
- Faça o download do GIT para Windows [aqui](https://git-scm.com/download/win).

#### Docker
1. Siga as instruções para instalar o WSL [aqui](https://learn.microsoft.com/pt-br/windows/wsl/install).
2. Instale o Docker no Windows conforme [estas instruções](https://docs.docker.com/desktop/install/windows-install/).

#### CURL
- Baixe o CURL [aqui](https://curl.se/download.html).

### Para Usuários do Linux:

#### Superusuário:
Para facilitar a instalação, certifique-se de saber a senha do seu usuário e de possuir os seguintes itens:

**Permissões:**
É necessário ter privilégios de administrador.

## Importante!

Para garantir o funcionamento adequado, é crucial possuir uma credencial SMTP válida para o sistema de e-mail. Isso é essencial para que os usuários recebam a confirmação da conta por e-mail.

---

## Como Instalar

### Para Usuários do Windows:

1. **Encontrando seu Endereço IP:**
   - Clique em "Iniciar" e vá para "Configurações".
   - Selecione "Rede e Internet".
   - Encontre o endereço IP clicando em "Ethernet" para conexões com fio ou "Wi-Fi" para conexões sem fio. O endereço IPv4 será visível.

2. **Acessando o Diretório Principal:**
   - Abra o terminal GIT BASH.

3. **Executando o Script de Instalação:**
   ```bash
   ./startup.sh
   ```

4. **Durante a Instalação:**
   - Durante a instalação, será solicitado seu endereço IP.
   - Informe o endereço IPv4 obtido na etapa 1.

### Para Usuários do Linux:

1. **Abrindo o Terminal:**
   - Dê permissões de execução:
     ```bash
     chmod +x startup-linux.sh
     ```
     
   - Execute o seguinte comando:
     ```bash
     sudo bash startup-linux.sh
     ```
   
---

**Conclusão da Instalação**

Após a conclusão do script, você verá um resultado semelhante à imagem abaixo:

![Instalação Concluída](./docs/installation-done.png)

**Portal do Administrador:**
- Acesse em: http://<IP da máquina informado>:8080

**Portal do Aluno:**
- Acesse em: http://<IP da máquina informado>:9090

---

# Dicas Finais

**Liberação de Portas**

Para acessar os Portais do Administrador e do Aluno na rede interna, certifique-se de liberar as seguintes portas:
- 8080 (Portal do Administrador)
- 9090 (Portal do Aluno)
- 3000 (API)

Para mais detalhes sobre como liberar portas, consulte os links abaixo:

- **Windows**: [Criar uma regra de porta de entrada](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)
