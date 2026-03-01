import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'editor_store.dart';
import 'range_slider.dart' as frs;
import 'recorder_store.dart';

class Looper extends StatefulWidget {
  final Color color;
  const Looper(this.color, {super.key});

  @override
  State<Looper> createState() => _LooperState();
}

class _LooperState extends State<Looper> {
  RangeValues? range;

  void _onSaveLoop(RecorderBottomSheetStore store) {
    if (range == null) return;
    Flushbar<void>(
      message: 'Saved ${range!.start} to ${range!.end}',
      duration: const Duration(seconds: 2),
    ).show(context);

    final current = store.currentAudioFile;
    if (current != null) {
      current.loopRange = range;
      changeAudioFile(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecorderBottomSheetStore>();
    if (store.state == RecorderState.stop && range != null) {
      range = null;
    }
    if (!((store.state == RecorderState.playing ||
            store.state == RecorderState.pausing) &&
        store.currentLength != null)) {
      return const SizedBox.shrink();
    }

    final defaultRange = RangeValues(0.0, store.currentLength!.inSeconds.toDouble());
    final lowerValue = range?.start ?? defaultRange.start;
    final upperValue = range?.end ?? defaultRange.end;

    return Container(
      color: widget.color,
      height: 100,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  child: const Text('Save Loop'),
                  onPressed: range == null ? null : () => _onSaveLoop(store),
                ),
              ),
            ],
          ),
          const Text('Looper:'),
          const SizedBox(height: 20),
          Expanded(
            child: frs.RangeSlider(
              min: 0,
              onChangeEnd: (endLowerValue, endUpperValue) {
                setLoopRange(RangeValues(endLowerValue, endUpperValue));
              },
              max: (store.currentLength!.inMilliseconds / 1000.0).toDouble(),
              showValueIndicator: true,
              lowerValue: lowerValue,
              upperValue: upperValue,
              onChanged: (newLowerValue, newUpperValue) {
                setState(() {
                  range = RangeValues(newLowerValue, newUpperValue);
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
