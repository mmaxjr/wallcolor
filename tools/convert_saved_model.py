#!/usr/bin/env python3
"""Convert a licensed TensorFlow SavedModel segmentation checkpoint to TFLite.

The source checkpoint is intentionally not downloaded by this script: select a
checkpoint with a compatible ADE20K label map and verify its redistribution
license before use. See README.md in this directory for expected tensors.
"""

import argparse
from pathlib import Path

import tensorflow as tf


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("saved_model", type=Path, help="Path to an exported TensorFlow SavedModel")
    parser.add_argument("--output", type=Path, default=Path("assets/models/wall_segmentation.tflite"))
    parser.add_argument("--float16", action="store_true", help="Use float16 weight quantization")
    args = parser.parse_args()

    converter = tf.lite.TFLiteConverter.from_saved_model(str(args.saved_model))
    if args.float16:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]

    model = converter.convert()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(model)
    print(f"Wrote {len(model)} bytes to {args.output}")
    print("Inspect input/output tensor shapes and validate ADE20K wall class mapping before app integration.")


if __name__ == "__main__":
    main()
