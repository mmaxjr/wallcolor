# WallColor

Aplicativo Flutter para pré-visualizar cores de tinta em paredes com segmentação semântica local.

## Estado

Base inicial da Fase 1: projeto Android (minSdk 24), permissão da câmera com mensagens para negação e bloqueio, preview ao vivo e paleta demonstrativa. A interface de modelo TFLite, execução em isolate, pós-processamento da máscara e shader foram iniciados, mas **a inferência ainda não está ligada ao stream e a recoloração ainda não está conectada ao preview**. Para habilitar isso é preciso selecionar, converter e validar um checkpoint ADE20K licenciado.

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
- `docs/decisions.md` e `docs/benchmarks.md`: decisões e espaço para métricas medidas.

## Modelo ADE20K

O app espera `assets/models/wall_segmentation.tflite`, com entrada RGB float32 NHWC e saída de logits por pixel. Esse arquivo não está incluído e a tela avisa que o modelo ainda não está configurado. Consulte [tools/README.md](tools/README.md) antes de selecionar/convertê-lo: confira licença, shapes, índice da classe `wall` e precisão após quantização.

## Desempenho e limitações

Não foram medidos FPS ou latência ainda. O alvo do projeto é inferência a 10–15 fps e preview a 30 fps em aparelho intermediário, mas isso precisa ser validado em dispositivo físico. O primeiro build evita converter YUV em Dart antes de existir medição; se virar gargalo, avalie pré-processamento Kotlin por platform channel. Bordas de teto, móveis e iluminação ruim também exigirão ajuste do modelo e da máscara.

O processamento de imagem planejado é local, sem backend. Configurações locais podem ser registradas em `.env` usando `.env.example` como referência; `.env` e pesos do modelo são ignorados pelo Git.
