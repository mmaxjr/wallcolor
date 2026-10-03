# Decisões técnicas

## Escopo deste primeiro corte

O repositório usa Android como única plataforma e minSdk 24. O nome provisório escolhido é WallColor. Esta etapa entrega a base do app, solicitação de permissão, preview ao vivo e componentes independentes de máscara/paleta. A inferência integrada e a recoloração ainda não estão habilitadas porque o checkpoint compatível e seus tensores de entrada/saída não foram fornecidos nem validados.

## Modelo

ADE20K fornece uma classe semântica para parede. Mantemos uma interface `SegmentationModel` para que o app não dependa do formato ou fornecedor do modelo. `tflite_flutter` foi escolhido porque a versão 0.12.1 expõe execução em isolate e delegate GPU Android. GPU não funciona em todos os aparelhos, portanto o carregamento tenta GPU e volta a CPU. Pesos externos não entram no Git até a licença, conversão, índice `wall` e tensores serem verificados.

## Isolate e taxa de frames

`IsolateInterpreter` executa inferência fora do isolate de UI. A integração da câmera deve adotar latest-frame-wins, sem fila crescente, e limitar a inferência a 10–15 fps. Não há benchmark nem compromisso de 30 fps nesta etapa.

## Composição

O shader preserva a luminância aproximada do pixel da câmera e mistura pela máscara e opacidade da tinta. A máscara suavizada deve ser amostrada no mesmo espaço UV do preview. O shader é apenas um contrato inicial: seu binding de textura e a sincronização com os frames ainda precisam ser conectados e medidos num dispositivo real.

## Pré-processamento

Não moveremos YUV para RGB em Dart até existir uma medição que demonstre gargalo. O fluxo da câmera usa YUV420 e resolução média; reaproveitamento de buffers e eventual implementação Kotlin via platform channel ficam para o passo de integração/benchmark.

## Configuração e privacidade

O processamento planejado é local. `.env` e arquivos de modelo locais estão ignorados; `.env.example` não contém segredos. Não há backend nem envio de frames.
