# Conversão do modelo

Coloque o artefato final em `assets/models/wall_segmentation.tflite` e não o versione até confirmar que a licença permite redistribuição. O modelo deve aceitar entrada RGB normalizada em float32 no formato NHWC e produzir logits por pixel; confirme o shape e o índice da classe `wall` no mapeamento ADE20K usado. O carregador atual supõe tensores dessa forma e precisa ser adaptado quando o checkpoint concreto for escolhido.

O projeto ainda não inclui script executável de conversão: não há um checkpoint de origem validado nem uma licença confirmada. Procedimento recomendado ao selecionar um checkpoint: exportar para ONNX/Core ML não é necessário; converter o modelo TensorFlow compatível com TFLite Converter, comparar float32 com float16/int8 em imagens ADE20K e medir a qualidade da máscara antes de escolher quantização. Registre URL, licença, checksum, shapes e índice `wall` aqui antes de integrar.
