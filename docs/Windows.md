### Pré requisitos - hardware:

- Processador: Intel Core I(i3,i5,i7,i9) de segunda geração ou superior, Intel Core Ultra, Intel Celeron, Intel XEON ou AMD Ryzen
- RAM: Mínimo de 4GB
- Armazenamento: 8GB disponíveis
- Habilite a virtualização de hardware na BIOS/UEFI.

### Pré requisitos - software:

- Windows 10 ou 11 64-bit: Home ou Pro versão 22H2 ou maior, ou Enterprise ou Education versão 22H2 ou maior.
- Privilégio de administrador.
- Winrar: [Clique aqui](https://support.microsoft.com/pt-br/windows/como-marcar-se-um-aplicativo-ou-programa-est%C3%A1-instalado-no-windows-5af73cea-f875-dfa0-4cd1-72a02aa06436#:~:text=Select%20Start%20%3E%20Settings%20%3E%20Apps.,followed%20by%20an%20alphabetical%20list.) para apreneder como verificar se o winrar está instalado. Caso não esteja, [clique aqui](https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-713br.exe) para instalar.

[Como verificar sua versão do windows e informações de hardware](https://support.microsoft.com/pt-br/windows/localizar-informa%C3%A7%C3%B5es-sobre-o-seu-dispositivo-windows-a66d52c8-3323-44fd-8f34-a9497bb935e1)

[Como habilitar a virtualização de hardware](https://learn.microsoft.com/pt-br/answers/questions/4039785/como-fa-o-para-ativar-virtualiza-o-de-hardware)

### Como instalar:

1. Baixe o zip do projeto
   - Mova o zip para a área de trabalho
   - Extraia o conteúdo do zip para a área de trabalho

2. Abra a pasta que foi extraida do zip.

3. Clique 2 vezes no arquivo de instalação `Instalador-Windows.cmd`.
   - Se aparecer uma janela pedindo permissão, clique em *SIM*

<img src="https://github.com/user-attachments/assets/91e7e817-aeb9-4f3e-aafe-7aab5cd73846" width="800" height="450" />

4. Ao iniciar o script de instalação, será feita uma verificação de algumas ferramentas necessárias para instalação do projeto. Caso alguma das ferramentas não esteja presente, a instalação da(s) ferramenta(s) será iniciada e, ao finalizar, o arquivo `Instalador-Windows.cmd` deverá ser iniciado novamente.

   **IMPORTANTE:** Este passo deve ser repetido até que todas as ferramentas estejam instaladas e a janela se pareça com a imagem abaixo.

<img src="https://github.com/user-attachments/assets/911b17a7-c46c-4a0a-8c69-4c898b1e22de" width="800" height="450" />

5. Para o caso de alguma ferramenta não estar instalada siga os seguintes passos:

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

   Nesta tela acima, clique em “skip” ou “pular” para continuar, se aparecer uma tela escrito "tell us about yourself" ou "Nos conte sobre você", clique em "skip" ou "pular" no canto inferior direito. Feito isso, a seguinte tela será apresentada:

   <img src="https://github.com/user-attachments/assets/cd035420-90bb-40db-a362-1529d7dcfe80" width="800" height="450" />

   Espere até que o processo seja iniciado e a seguinte tela seja apresentada:

   <img src="https://github.com/user-attachments/assets/506ef228-fede-4257-a939-d5ba4f6ce7b4" width="800" height="450" />

   Isso sinaliza que a instalação foi concluída com sucesso e você deverá iniciar novamente o arquivo `Instalador-Windows.cmd`.

6. Ao concluir a instalação das ferramentas necessárias ou caso já estejam instaladas, inicie novamente o arquivo `Instalador-Windows.cmd` e a instalação do projeto deverá ser iniciada.

7. Ao fim da instalação a seguinte tela será apresentada:

<img src="https://github.com/user-attachments/assets/2e67e1eb-9cb7-41e6-b48a-47ed4165de4c" width="800" height="450" />

Os links para os portais estarão disponíveis nesta tela e podem ser acessados.

   - *IMPORTANTE:* Anote os links de acesso em algum lugar seguro e de fácil acesso, pois o acesso do EduEdu+ deve ser feito sempre através deles.

8. Aperte “Enter” para finalizar a instalação.
