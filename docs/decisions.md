# Decisões técnicas

## Escopo deste primeiro corte

O repositório usa Android como única plataforma e minSdk 24. O nome escolhido é WallColor. A tela coordena estado via Riverpod; os serviços de câmera e ML ficam em camadas próprias. Sem o arquivo TFLite local não é possível testar a inferência de ponta a ponta.

## Modelo

ADE20K fornece uma classe semântica para parede. Mantemos uma interface `SegmentationModel` para que o app não dependa do formato ou fornecedor do modelo. `tflite_flutter` foi escolhido porque a versão 0.12.1 expõe execução em isolate e delegate GPU Android. GPU não funciona em todos os aparelhos, portanto o carregamento tenta GPU e volta a CPU. Pesos externos não entram no Git até a licença, conversão, índice `wall` e tensores serem verificados.

## Isolate e taxa de frames

`IsolateInterpreter` executa inferência fora do isolate de UI. A política latest-frame-wins descarta frames enquanto o modelo trabalha, sem fila crescente. A taxa padrão é 12 fps e pode ser ajustada em `assets/config/.env`. O preview da câmera continua sendo renderizado pelo Flutter. Não há benchmark nem compromisso de 30 fps sem medição em aparelhos.

## Composição

O overlay usa `ColorFilter.mode` com `BlendMode.color` para trocar matiz/saturação sem substituir a luminância. Uma imagem de máscara alfa limita o efeito à classe parede; a camada mantém a textura e as sombras da prévia abaixo. `shaders/wall_recolor.frag` fica como alternativa futura se for necessário controlar a composição com mais precisão.

## Pré-processamento

O fluxo da câmera usa YUV420 e amostra diretamente na resolução do tensor, reaproveitando o buffer RGB entre inferências. Se isso virar gargalo, mova a conversão para Kotlin via platform channel.

## Configuração e privacidade

O processamento planejado é local. `.env` e arquivos de modelo locais estão ignorados; `.env.example` não contém segredos. Não há backend nem envio de frames.
