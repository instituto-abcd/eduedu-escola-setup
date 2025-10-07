# Guia de Instalação EduEdu

## Antes de Começar

Antes de iniciar a instalação, verifique seu sistema operacional. Caso esteja utilizando o Windows siga [a documentação de instalação para windows](docs/Windows.md), mas caso esteja utilizando Linux siga a documentação a baixo.

### Pré requisitos - Linux:

#### Superusuário:

Para facilitar a instalação, certifique-se de saber a senha do seu usuário e de possuir os seguintes itens:

#### Permissões:

É necessário ter privilégios de administrador.

#### Credencial SMTP

Para garantir o funcionamento adequado, é crucial possuir uma credencial SMTP válida para o sistema de e-mail. Isso é essencial para que os usuários recebam a confirmação da conta por e-mail.

---

### Como Instalar

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

## Dicas Finais

**Liberação de Portas**

Para acessar os Portais do Administrador e do Aluno na rede interna, certifique-se de liberar as seguintes portas:

- 8080 (Portal do Administrador)
- 9090 (Portal do Aluno)
- 3000 (API)

Para mais detalhes sobre como liberar portas, consulte os links abaixo:

- **Windows**: [Criar uma regra de porta de entrada](https://learn.microsoft.com/pt-br/windows/security/operating-system-security/network-security/windows-firewall/create-an-inbound-port-rule)
