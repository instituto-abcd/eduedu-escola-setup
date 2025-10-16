### Pré requisitos - hardware:

- Processador 64-bit com tecnologia de tradução de endereços de segundo nível (SLAT)
- 4GB system RAM
- Habilite a virtualização de hardware na BIOS/UEFI.
- CPU com suporte a AVX.

### Pré requisitos - software:

- Windows 11 64-bit: Home ou Pro versão 22H2 ou maior, ou Enterprise ou Education versão 22H2 ou maior.
- Windows 10 64-bit: Mínimo necessário é Home ou Pro 22H2 (build 19045) ou maior, ou Enterprise ou Education 22H2 (build 19045) ou maior.
- Privilégio de administrador.

[Como verificar sua versão do windows e build](https://learn.microsoft.com/pt-br/windows/client-management/client-tools/windows-version-search)

[Como habilitar a virtualização de hardware](https://learn.microsoft.com/pt-br/answers/questions/4039785/como-fa-o-para-ativar-virtualiza-o-de-hardware)

### Como instalar:

1. Mova os arquivos do projeto para o seu computador.

2. Execute o arquivo de instalação `Instalador-Windows.cmd`.

<img src="https://github.com/user-attachments/assets/91e7e817-aeb9-4f3e-aafe-7aab5cd73846" width="800" height="450" />

3. Ao iniciar o script de instalação, será feita uma verificação de algumas ferramentas necessárias para instalação do projeto. Caso alguma das ferramentas necessárias não esteja presente, a instalação da(s) ferramenta(s) será iniciada e, ao finalizar, o arquivo `Instalador-Windows.cmd` deverá ser iniciado novamente.

   **IMPORTANTE:** Este passo deve ser repetido até que todas as ferramentas estejam instaladas e a janela se pareça com a imagem abaixo.

<img src="https://github.com/user-attachments/assets/911b17a7-c46c-4a0a-8c69-4c898b1e22de" width="800" height="450" />

4. Para o caso de alguma ferramenta não estar instalada siga os seguintes passos:

   a. **Winget não instalado:**

   <img src="https://github.com/user-attachments/assets/5460da8e-405e-42c0-848c-8f02ba83e7bf" width="800" height="450" />

   Neste caso aperte a tecla “s” e em seguida “Enter” para confirmar a instalação e, ao finalizar, a janela será fechada automaticamente e o arquivo `Instalador-Windows.cmd` deverá ser iniciado novamente.

   b. **WSL não instalado:**

   <img src="https://github.com/user-attachments/assets/83d635df-fbb8-4da6-b472-ae0a528af375" width="800" height="450" />

   Neste caso aperte a tecla “s” para confirmar a instalação e, ao finalizar, uma nova confirmação será apresentada:

   <img src="https://github.com/user-attachments/assets/88be7673-da75-4f0a-aefd-b17a92ca114d" width="800" height="450" />

   Para concluir a instalação da ferramenta WSL, reinicie o computador apertando “s” e em seguida “Enter”. Após a reinicialização, execute novamente o arquivo `Instalador-Windows.cmd`.

   c. **Docker não instalado:**

   <img src="https://github.com/user-attachments/assets/1230922f-c63e-472a-a429-1f53f982c6b5" width="800" height="450" />

   Neste caso aperte “s” para confirmar a instalação. Ao finalizar, uma janela do Docker Desktop será aberta:

   <img src="https://github.com/user-attachments/assets/b184d01f-fb43-4be6-8847-69b4f3441ef7" width="800" height="450" />

   Clique em “Accept” ou “Aceitar” para continuar e uma nova janela será apresentada:

   <img src="https://github.com/user-attachments/assets/35ff26b8-25de-4443-9644-722502cdd687" width="800" height="450" />

   Nesta tela acima, clique em “skip” ou “pular” para continuar e a seguinte tela será apresentada:

   <img src="https://github.com/user-attachments/assets/cd035420-90bb-40db-a362-1529d7dcfe80" width="800" height="450" />

   Espere até que o processo seja iniciado e a seguinte tela seja apresentada:

   <img src="https://github.com/user-attachments/assets/506ef228-fede-4257-a939-d5ba4f6ce7b4" width="800" height="450" />

   Isso sinaliza que a instalação foi concluída com sucesso e você deverá iniciar novamente o arquivo `Instalador-Windows.cmd`.

5. Ao concluir a instalação das ferramentas necessárias ou caso já estejam instaladas, inicie novamente o arquivo `Instalador-Windows.cmd` e a instalação do projeto deverá ser iniciada.

6. Ao fim da instalação a seguinte tela será apresentada:

<img src="https://github.com/user-attachments/assets/2e67e1eb-9cb7-41e6-b48a-47ed4165de4c" width="800" height="450" />

Os links para os portais estarão disponíveis nesta tela e podem ser acessados.

7. Aperte “Enter” para finalizar a instalação.
