# Fechamento de Comissões

Aplicação web para o fechamento mensal de comissões de uma rede de lojas do varejo, contemplando consultores de vendas, gerentes de loja e supervisão regional.

## Sobre esta versão

Este projeto foi desenvolvido para uma empresa do varejo e está em uso em produção, com dados reais, pelas equipes de loja e pelo departamento pessoal.

Esta é uma versão de demonstração, publicada para fins de portfólio. Para preservar informações confidenciais da empresa:

- os nomes das lojas, dos colaboradores e da empresa foram removidos ou substituídos por nomes fictícios;
- os valores de metas e os percentuais das regras de comissão foram alterados, mantendo a mesma estrutura e a mesma lógica de cálculo;
- os dados exibidos são fictícios e gerados para demonstração;
- o endereço e a configuração do ambiente de produção não fazem parte deste repositório.

## Contexto

O fechamento de comissões era feito em planilhas, preenchidas por loja e consolidadas manualmente. A aplicação substituiu esse processo por uma ferramenta única, que calcula os resultados no momento do preenchimento, sinaliza pendências e gera o relatório consolidado para pagamento.

As regras de cálculo foram migradas a partir das planilhas originais e validadas contra o próprio Excel: os mesmos cenários de teste foram calculados pela planilha e pela aplicação, com resultados idênticos.

## Funcionalidades

- Cadastro de metas e resultados por loja e por consultor, com validação das unidades (moeda, percentual, quantidade e tempo).
- Cálculo da faixa de comissão de cada consultor, com base no atingimento das metas de venda e em nove indicadores de desempenho.
- Cálculo da comissão em reais, aplicando o percentual da faixa sobre a receita realizada.
- Cálculo das bonificações por indicador.
- Cálculo da comissão das gerentes, com base nos desafios financeiros e nos indicadores da loja, e suporte a lojas com modelo de prêmios fixos por critério atingido.
- Cálculo da premiação da supervisão, com base no faturamento das lojas sob sua gestão.
- Apuração do total a pagar por pessoa e do total geral do fechamento.
- Painel por loja, com visão geral de atingimento por indicador e detalhamento por consultor.
- Relatório consolidado de fechamento, com indicação de pendências de preenchimento.
- Exportação do fechamento em planilha Excel (.xlsx), com valores numéricos e formatação de moeda e percentual.
- Tela de acesso com o conteúdo da aplicação criptografado.
- Compartilhamento dos dados entre usuários, com tratamento de alterações simultâneas.

## Arquitetura

| Componente | Descrição |
|---|---|
| `index.html` | Aplicação completa em um único arquivo (HTML, CSS e JavaScript), sem dependência de framework. |
| `template/entrada.html` | Tela de acesso. Recebe a aplicação criptografada e a decifra no navegador com a senha informada. |
| `tools/publicar.ps1` | Script que criptografa a aplicação e gera a versão publicada. |
| `netlify/functions/dados.mjs` | Função de servidor que armazena e devolve os dados compartilhados (Netlify Functions e Netlify Blobs). |

### Segurança

- **Conteúdo da aplicação:** criptografado com AES-256-GCM. A chave é derivada da senha com PBKDF2-SHA256 (600.000 iterações). Sem a senha, apenas a tela de acesso é exibida.
- **Dados compartilhados:** criptografados no navegador antes do envio, com uma chave derivada da senha por HKDF-SHA256. O servidor armazena somente o conteúdo cifrado.
- **Controle de acesso:** a leitura e a gravação exigem um código derivado da senha. O servidor conhece apenas o hash desse código, armazenado em variável de ambiente, e o compara em tempo constante.
- **Alterações simultâneas:** cada gravação gera uma nova versão. Se outro usuário tiver salvo alterações, a gravação é interrompida e o usuário escolhe entre carregar a versão mais recente ou manter as próprias alterações. As versões anteriores são mantidas como histórico.

## Como executar

Abra o arquivo `index.html` em um navegador atualizado. A aplicação é carregada com dados de exemplo; o botão "Restaurar dados de exemplo" retorna ao estado inicial. Nesse modo, os dados ficam armazenados apenas no navegador.

Para publicar a versão protegida por senha, com compartilhamento de dados:

1. Gerar a versão publicada: `pwsh tools/publicar.ps1 -Senha "<senha>"`.
2. Configurar no Netlify a variável `ACESSO_HASH` com o valor exibido pelo script.
3. Instalar as dependências (`npm install`) e publicar com a Netlify CLI: `netlify deploy --prod --no-build --dir publicar --functions netlify/functions`.

## Tecnologias

HTML, CSS e JavaScript, Web Crypto API, SheetJS (exportação para Excel), Netlify Functions, Netlify Blobs e PowerShell.

## Licença

Distribuído sob a licença MIT. Consulte o arquivo `LICENSE`.
