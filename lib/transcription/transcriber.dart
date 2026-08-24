import 'audio_input_decoder.dart';
import 'model_catalog.dart';
import 'model_download_manager.dart';
import 'basic_pitch_runner.dart';
import 'pesto_runner.dart';
import 'swift_f0_runner.dart';
import 'tflite_pitch_runners.dart';
import 'types.dart';
import 'yin_transcriber.dart';

class OnDeviceTranscriber {
  OnDeviceTranscriber({ModelDownloadManager? downloads})
      : _downloads = downloads ?? ModelDownloadManager();

  final ModelDownloadManager _downloads;

  Future<TranscriptionResult> transcribe(
    String audioPath,
    OnDeviceModel model, {
    TranscriptionOptions options = const TranscriptionOptions(),
    DownloadProgress? onDownloadProgress,
  }) async {
    final info = modelInfo(model);
    if (info.runtime == TranscriptionRuntime.dart) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes = const YinTranscriber().transcribe(
        audio,
        options,
        pyinStyle: model == OnDeviceModel.pyin,
      );
      return TranscriptionResult(
        model: model,
        notes: _quantize(notes, options),
        warnings: const [],
      );
    }
    final artifact =
        await _downloads.ensureDownloaded(info, onProgress: onDownloadProgress);
    if (model == OnDeviceModel.swiftF0) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes =
          await SwiftF0Runner().transcribe(audio, artifact.file, options);
      return TranscriptionResult(
          model: model, notes: _quantize(notes, options));
    }
    if (model == OnDeviceModel.basicPitch) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes =
          await BasicPitchRunner().transcribe(audio, artifact.file, options);
      return TranscriptionResult(
          model: model, notes: _quantize(notes, options));
    }
    if (model == OnDeviceModel.crepeTiny || model == OnDeviceModel.crepeFull) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes =
          await CrepeTfliteRunner().transcribe(audio, artifact.file, options);
      return TranscriptionResult(
          model: model, notes: _quantize(notes, options));
    }
    if (model == OnDeviceModel.spice) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes =
          await SpiceTfliteRunner().transcribe(audio, artifact.file, options);
      return TranscriptionResult(
          model: model, notes: _quantize(notes, options));
    }
    if (model == OnDeviceModel.pesto) {
      final audio = await AudioInputDecoder().decode(audioPath);
      final notes =
          await PestoRunner().transcribe(audio, artifact.file, options);
      return TranscriptionResult(
          model: model, notes: _quantize(notes, options));
    }
    throw ModelUnavailableException(
        '${info.title} is not installed in this build yet.');
  }

  List<MidiNote> _quantize(List<MidiNote> notes, TranscriptionOptions options) {
    final tempo = options.tempoBpm;
    if (tempo == null || notes.isEmpty) return notes;
    final gridMicros = 60000000 / tempo / options.quantizationDivisions;
    Duration snap(Duration value) => Duration(
        microseconds:
            (value.inMicroseconds / gridMicros).round() * gridMicros.round());
    return notes.map((note) {
      final start = snap(note.start);
      final end = snap(note.end);
      return note.copyWith(
        start: start,
        end: end <= start ? start + options.minimumNoteLength : end,
      );
    }).toList();
  }
}
