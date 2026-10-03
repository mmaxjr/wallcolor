# WallColor

Aplicativo Flutter para pré-visualizar cores de tinta em paredes com segmentação semântica local.

## Objetivo do projeto

Este projeto tem como base o aprendizado e a experimentação. Já trabalho com *machine vision* e quis explorar como adaptar esse conhecimento para um aplicativo de celular: segmentar paredes pela câmera e visualizar diferentes cores de tinta em tempo real, com processamento local no Android. O WallColor também serve para estudar os compromissos de levar visão computacional para dispositivos móveis, como latência, consumo de recursos, qualidade das bordas e integração entre Flutter, Android e TensorFlow Lite.

## Estado

Fase 1 inclui preview de câmera, amostragem YUV420, inferência TFLite em isolate, suavização temporal, depuração da máscara e recoloração preservando luminância. O modelo de teste espera RGB `uint8` em `[1,512,512,3]` e devolve IDs de classe `int32` em `[1,512,512]`. Consulte [assets/models/README.md](assets/models/README.md) para origem, licença, classes e instalação local do peso; o arquivo do modelo é ignorado pelo Git.

## Rodar

Requisitos: Flutter stable, Android SDK e um dispositivo/emulador Android com câmera. A permissão de câmera é necessária.

```bash
flutter pub get
flutter run
```

Verificações locais:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Organização

- `lib/core`: configurações e recursos comuns.
- `lib/data/camera`: lifecycle do preview de câmera.
- `lib/data/ml`: interface TFLite, isolate e pós-processamento de máscara.
- `lib/domain`: entidades sem regras de apresentação.
- `lib/presentation`: tela, paleta e estado de interface.
- `assets/palettes/starter.json`: cores iniciais de demonstração.
- `shaders/wall_recolor.frag`: base para mistura da tinta preservando luminância.
- `assets/models/`: destino local para o modelo validado (pesos ignorados pelo Git).
- `assets/config/default.env`: valores padrão de taxa de inferência e suavização; crie `assets/config/.env` para sobrepor localmente.
- `docs/decisions.md` e `docs/benchmarks.md`: decisões e espaço para métricas medidas.

## Modelo ADE20K

O modelo usado localmente é DeepLabV3 MobileNetV2 quantizado do MLPerf Mobile Models. Seu mapa tem a classe `wall` no índice 1 (índice 0 é `ignore`). O adaptador converte a entrada e decodifica a saída `int32` por pixel. O arquivo `.tflite` é excluído do Git; veja [assets/models/README.md](assets/models/README.md) para baixá-lo em uma cópia nova.

Para configurar variáveis localmente, copie `.env.example` para `assets/config/.env`; esse caminho é ignorado pelo Git.

## Desempenho e limitações

Não foram medidos FPS ou latência ainda. O alvo do projeto é inferência a 10–15 fps e preview a 30 fps em aparelho intermediário, mas isso precisa ser validado em dispositivo físico. O pré-processamento amostra YUV420 diretamente na resolução de entrada para evitar um frame RGB intermediário; se isso virar gargalo, avalie Kotlin por platform channel. Bordas de teto, móveis e iluminação ruim também exigirão ajuste do modelo e da máscara.

O processamento de imagem planejado é local, sem backend. Configurações locais podem ser registradas em `.env` usando `.env.example` como referência; `.env` e pesos do modelo são ignorados pelo Git.
