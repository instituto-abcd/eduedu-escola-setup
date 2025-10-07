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

![image.png](attachment:00fef156-7d18-4842-b79f-6d21dd683d31:image.png)

3. Ao iniciar o script de instalação, será feita uma verificação de algumas ferramentas necessárias para instalação do projeto. Caso alguma das ferramentas necessárias não esteja presente, a instalação da(s) ferramenta(s) será iniciado e, ao finalizar a instalação, o arquivo de instalação startup-windows.cmd devera ser iniciado novamente.

   IMPORTANTE: Este passo deve ser repetido até que todas as ferramentas estejam instaladas e a janela se pareça com a imagem abaixo.

   ![image.png](attachment:1f062bbf-c038-4a85-ba61-bdede605fca4:image.png)

4. Para o caso de alguma ferramenta não estiver instalada siga os seguintes passos:

   1. Winget não instalado:

   ![image.png](attachment:3e0e7a83-4fb9-4502-87d0-95dc726f559d:image.png)

   Neste caso aperte a tecla “s” e em seguida “Enter” para confirmar a instalação e, ao finalizar a instalação, a janela será fechada automaticamente e o arquivo startup-windows.cmd devera ser iniciado novamente.

   b. WSL não instalado:

   ![image.png](attachment:0ef4fcd5-af81-41c2-b89e-3d4f23c0455a:image.png)

   Neste caso aperte a tecla “s” para confirmar a instalação e, ao finalizar a instalação, uma nova confirmação será apresentada:

   ![image.png](attachment:ec881d01-4a9b-49b9-a9f3-0c3694532f5c:image.png)

   Para concluir a instalação da ferramenta WSL reinicie o computador apertando “s” e em seguida “Enter”. Após concluída a reinicialização, o arquivo startup-windows.cmd devera ser iniciado novamente.

   c. Docker não instalado:

   ![image.png](attachment:76b2ff67-43ed-4c9a-81c4-53c868d34f46:image.png)

   Neste caso aperte a tecla “s” para confirmar a instalação. Ao finalizar a instalação uma janela do Docker Desktop será aberta:

   ![image.png](attachment:177ab87e-10d2-411d-bfa8-b08623aeff3a:image.png)

   Clique em “Accept” ou “Aceitar” para continuar a instalação e uma nova janela será apresentada:

   ![image.png](attachment:8d7c3616-ed98-45d0-98fe-f38242b22f7e:image.png)

   Nesta tela acima, clique em “skip” ou “pular” para continuar a instalação e a seguinte tela será apresentada:

   ![image.png](attachment:d33176bb-e4bb-4145-9558-d2b3ce795db1:image.png)

   Espera até que o processo seja iniciado e a seguinte tela seja apresentada:

   ![image.png](attachment:6741fac4-61ae-4168-909f-5d23814cd789:image.png)

   Isso sinalizara que a instalação foi concluída com sucesso e você devera iniciar novamente o arquivo startup-windows.cmd.

5. Ao concluir a instalação das ferramentas necessárias ou caso já estejam instaladas, Inicie o arquivo startup-windows.cmd novamente e a instalação do projeto deverá ser iniciada.

6. Ao fim da instalação a seguinte tela será apresentada:

![image.png](attachment:40bf94c0-058d-4328-a592-c39301d23883:image.png)

O link para os portais estarão disponíveis nesta tela e podem ser acessados.

7. Aperte “enter” para finalizar a instalação.
