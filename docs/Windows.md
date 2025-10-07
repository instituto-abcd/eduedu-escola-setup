### Pré requisitos - hardware:

- Processador 64-bit com tecnologia de tradução de endereços de segundo nível (SLAT)
- 4GB system RAM
- Habilite a virtualização de hardware na BIOS/UEFI.
- CPU com suporte a AVX.

### Pré requisitos - software:

- Windows 11 64-bit: Home ou Pro versão 22H2 ou maior, ou Enterprise ou Education versão 22H2 ou maior.
- Windows 10 64-bit: Minimo necessário é Home ou Pro 22H2 (build 19045) ou maior, ou Enterprise ou Education 22H2 (build 19045) or maior.
- Privilégio de administrador.

### Como instalar:

1. Mova os arquivos do projeto para o seu computador.

2. Execute o arquivo de instalação startup-windows.cmd.

![1](https://github.com/user-attachments/assets/91e7e817-aeb9-4f3e-aafe-7aab5cd73846)

3. Ao iniciar o script de instalação, será feita uma verificação de algumas ferramentas necessárias para instalação do projeto. Caso alguma das ferramentas necessárias não esteja presente, a instalação da(s) ferramenta(s) será iniciado e, ao finalizar a instalação, o arquivo de instalação startup-windows.cmd devera ser iniciado novamente.

   IMPORTANTE: Este passo deve ser repetido até que todas as ferramentas estejam instaladas e a janela se pareça com a imagem abaixo.

![2](https://github.com/user-attachments/assets/911b17a7-c46c-4a0a-8c69-4c898b1e22de)

4. Para o caso de alguma ferramenta não estiver instalada siga os seguintes passos:

   a. Winget não instalado:

   <img width="908" height="346" alt="image(1)" src="https://github.com/user-attachments/assets/5460da8e-405e-42c0-848c-8f02ba83e7bf" />

   Neste caso aperte a tecla “s” e em seguida “Enter” para confirmar a instalação e, ao finalizar a instalação, a janela será fechada automaticamente e o arquivo startup-windows.cmd devera ser iniciado novamente.

   b. WSL não instalado:

   <img width="934" height="280" alt="image(2)" src="https://github.com/user-attachments/assets/83d635df-fbb8-4da6-b472-ae0a528af375" />

   Neste caso aperte a tecla “s” para confirmar a instalação e, ao finalizar a instalação, uma nova confirmação será apresentada:

   <img width="1300" height="304" alt="image(3)" src="https://github.com/user-attachments/assets/88be7673-da75-4f0a-aefd-b17a92ca114d" />

   Para concluir a instalação da ferramenta WSL reinicie o computador apertando “s” e em seguida “Enter”. Após concluída a reinicialização, o arquivo startup-windows.cmd devera ser iniciado novamente.

   c. Docker não instalado:

  <img width="791" height="247" alt="image(4)" src="https://github.com/user-attachments/assets/1230922f-c63e-472a-a429-1f53f982c6b5" />

   Neste caso aperte a tecla “s” para confirmar a instalação. Ao finalizar a instalação uma janela do Docker Desktop será aberta:

   <img width="1005" height="637" alt="image(5)" src="https://github.com/user-attachments/assets/b184d01f-fb43-4be6-8847-69b4f3441ef7" />

   Clique em “Accept” ou “Aceitar” para continuar a instalação e uma nova janela será apresentada:

   <img width="1609" height="850" alt="image(6)" src="https://github.com/user-attachments/assets/35ff26b8-25de-4443-9644-722502cdd687" />

   Nesta tela acima, clique em “skip” ou “pular” para continuar a instalação e a seguinte tela será apresentada:

   <img width="1593" height="817" alt="image(7)" src="https://github.com/user-attachments/assets/cd035420-90bb-40db-a362-1529d7dcfe80" />

   Espera até que o processo seja iniciado e a seguinte tela seja apresentada:

   <img width="1593" height="742" alt="image(8)" src="https://github.com/user-attachments/assets/506ef228-fede-4257-a939-d5ba4f6ce7b4" />

   Isso sinalizara que a instalação foi concluída com sucesso e você devera iniciar novamente o arquivo startup-windows.cmd.

5. Ao concluir a instalação das ferramentas necessárias ou caso já estejam instaladas, Inicie o arquivo startup-windows.cmd novamente e a instalação do projeto deverá ser iniciada.

6. Ao fim da instalação a seguinte tela será apresentada:
<img width="1678" height="1230" alt="image(9)" src="https://github.com/user-attachments/assets/2e67e1eb-9cb7-41e6-b48a-47ed4165de4c" />

O link para os portais estarão disponíveis nesta tela e podem ser acessados.

7. Aperte “enter” para finalizar a instalação.
