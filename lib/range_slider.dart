import 'package:flutter/material.dart' as m;

typedef RangeChanged = void Function(double lowerValue, double upperValue);

class RangeSlider extends m.StatelessWidget {
  final double min;
  final double max;
  final double lowerValue;
  final double upperValue;
  final RangeChanged onChanged;
  final RangeChanged? onChangeEnd;
  final bool showValueIndicator;

  const RangeSlider({
    super.key,
    required this.min,
    required this.max,
    required this.lowerValue,
    required this.upperValue,
    required this.onChanged,
    this.onChangeEnd,
    this.showValueIndicator = false,
  });

  @override
  m.Widget build(m.BuildContext context) {
    final values = m.RangeValues(
      lowerValue.clamp(min, max),
      upperValue.clamp(min, max),
    );

    return m.SliderTheme(
      data: m.Theme.of(context).sliderTheme.copyWith(
            showValueIndicator: showValueIndicator
                ? m.ShowValueIndicator.onDrag
                : m.ShowValueIndicator.never,
          ),
      child: m.RangeSlider(
        min: min,
        max: max,
        values: values,
        labels: showValueIndicator
            ? m.RangeLabels(
                values.start.toStringAsFixed(1),
                values.end.toStringAsFixed(1),
              )
            : null,
        onChanged: (v) => onChanged(v.start, v.end),
        onChangeEnd:
            onChangeEnd == null ? null : (v) => onChangeEnd!(v.start, v.end),
      ),
    );
  }
}
