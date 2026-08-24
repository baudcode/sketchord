# PESTO model artifact

The mobile runner expects the official PESTO v2 streaming ONNX graph exported
with the fixed profile below:

| Checkpoint | Sample rate | Audio chunk | Cache floats |
| --- | ---: | ---: | ---: |
| `mir-1k_g7` | 44,100 Hz | 1,024 | 3,584 |

Create it on a trusted release machine with:

```sh
./tool/export_pesto_onnx.sh /absolute/path/pesto_mir-1k_g7_44100_1024.onnx
```

The script pins the official PESTO source revision and runs its own ONNX
validation. It also forces the legacy PyTorch exporter because PyTorch 2.9's
new exporter currently cannot export PESTO's dynamic `torch.roll` operation.

Publish the resulting file to HTTPS storage, calculate its SHA-256 with the
last script line, then add the URL, file name, hash and version to the app's
signed remote model manifest. Do not add a generic upstream download URL: the
upstream repository distributes checkpoints, not a canonical ONNX artifact.

PESTO is distributed under LGPL-3.0. Product/legal review is required before
shipping an artifact or enabling this entry in a production model manifest.
