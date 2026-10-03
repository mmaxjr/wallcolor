# WallColor

Aplicativo Flutter para pré-visualizar cores de tinta em paredes com segmentação semântica local.

## Estado

Fase 1 está implementada para um modelo ADE20K compatível: o app pede permissão, mostra a câmera, amostra frames YUV420, roda TFLite num isolate, suaviza a máscara, permite depurar a máscara e recolore só os pixels selecionados preservando a luminância com `BlendMode.color`. A paleta é lida de JSON e o processamento é limitado a 12 fps. **O modelo TFLite não está incluído**, então, sem instalá-lo localmente, o app mostra a câmera e informa que a segmentação não está disponível.

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

O app espera `assets/models/wall_segmentation.tflite`, com entrada RGB float32 NHWC em `[0,1]` e saída float32 NHWC `[1, altura, largura, classes]`. O índice de `wall` padrão é 0, seguindo a ordem ADE20K, mas confira o mapeamento específico do checkpoint. O carregador tenta GPU e volta para CPU. Esse arquivo não está incluído e a tela avisa que o modelo ainda não está configurado. Consulte [tools/README.md](tools/README.md) antes de selecionar/convertê-lo: confira licença, shapes, índice da classe `wall` e precisão após quantização.

Para configurar variáveis localmente, copie `.env.example` para `assets/config/.env`; esse caminho é ignorado pelo Git.

## Desempenho e limitações

Não foram medidos FPS ou latência ainda. O alvo do projeto é inferência a 10–15 fps e preview a 30 fps em aparelho intermediário, mas isso precisa ser validado em dispositivo físico. O pré-processamento amostra YUV420 diretamente na resolução de entrada para evitar um frame RGB intermediário; se isso virar gargalo, avalie Kotlin por platform channel. Bordas de teto, móveis e iluminação ruim também exigirão ajuste do modelo e da máscara.

O processamento de imagem planejado é local, sem backend. Configurações locais podem ser registradas em `.env` usando `.env.example` como referência; `.env` e pesos do modelo são ignorados pelo Git.
