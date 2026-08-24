# SwiftF0 model artifact

The upstream MIT-licensed SwiftF0 ONNX graph declares ONNX opset 20. The
mobile ONNX Runtime bundled by this app supports only released opsets through
19, and a mechanical conversion to opset 19 still uses `Pad`, which this mobile
runtime does not include. Do not publish the upstream graph, or a simple opset
conversion of it, in the app manifest.

Before enabling SwiftF0, produce a graph rebuilt/reduced against the exact
Android and iOS ONNX Runtime operator configuration, then run it through the
device integration test and publish the verified artifact via HTTPS with a
SHA-256. The Dart runner is ready for that artifact; the published upstream
graph is intentionally gated so users never download a model that cannot load.
