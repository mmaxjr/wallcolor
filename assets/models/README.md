# Model assets

The local `wall_segmentation.tflite` is the quantized ADE20K DeepLabV3 MobileNetV2 model from MLPerf Mobile Models. Its SHA-256 is `2D58C681D81B5E181816B81CC815B82EDF3DAAD905B4D7D35AFADE80AEE93B5F`.

- Input: `uint8`, `[1, 512, 512, 3]`, RGB pixel values.
- Output: `int32`, `[1, 512, 512]`, one ADE20K class ID per pixel.
- The output label map includes `ignore` at index 0 and `wall` at index 1.
- Source: [mlcommons/mobile_models](https://github.com/mlcommons/mobile_models/tree/main/v0_7/tflite).
- License: [Apache-2.0](https://github.com/mlcommons/mobile_models/blob/main/LICENSE.md).

The `.tflite` weights are excluded from Git by `.gitignore`; download the model from the source above into this folder before building from a fresh clone.
