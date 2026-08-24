import 'types.dart';

/// Source-of-truth for the selectable on-device models. Keep this list in the
/// same order as the research document so adding a new runner never changes a
/// saved user's model preference.
const onDeviceModels = <OnDeviceModelInfo>[
  OnDeviceModelInfo(
    model: OnDeviceModel.basicPitch,
    title: 'Basic Pitch',
    runtime: TranscriptionRuntime.tflite,
    assetPath: 'assets/models/basic_pitch.tflite',
    license: 'Apache-2.0',
    directNotes: true,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.crepeTiny,
    title: 'CREPE tiny',
    runtime: TranscriptionRuntime.tflite,
    assetPath: 'assets/models/crepe_tiny.tflite',
    license: 'MIT',
    directNotes: false,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.crepeFull,
    title: 'CREPE full',
    runtime: TranscriptionRuntime.tflite,
    assetPath: 'assets/models/crepe_full.tflite',
    license: 'MIT',
    directNotes: false,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.pesto,
    title: 'PESTO',
    runtime: TranscriptionRuntime.onnx,
    assetPath: 'assets/models/pesto.onnx',
    license: 'LGPL-3.0; verify the selected checkpoint separately',
    directNotes: false,
    productionReady: false,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.swiftF0,
    title: 'SwiftF0',
    runtime: TranscriptionRuntime.onnx,
    assetPath: 'assets/models/swiftf0.onnx',
    license: 'MIT',
    directNotes: false,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.spice,
    title: 'SPICE',
    runtime: TranscriptionRuntime.tflite,
    assetPath: 'assets/models/spice.tflite',
    license: 'Apache-2.0',
    directNotes: false,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.aubioYin,
    title: 'aubio YIN-compatible',
    runtime: TranscriptionRuntime.dart,
    assetPath: '',
    license: 'App implementation (no aubio binary bundled)',
    directNotes: false,
    productionReady: true,
  ),
  OnDeviceModelInfo(
    model: OnDeviceModel.pyin,
    title: 'pYIN-compatible',
    runtime: TranscriptionRuntime.dart,
    assetPath: '',
    license: 'App implementation (no librosa code bundled)',
    directNotes: false,
    productionReady: true,
  ),
];

OnDeviceModelInfo modelInfo(OnDeviceModel model) =>
    onDeviceModels.firstWhere((entry) => entry.model == model);
