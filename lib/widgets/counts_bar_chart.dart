import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class ChartBar {
  const ChartBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

/// Histogramme simple (nombre total par type d'activité).
class CountsBarChart extends StatelessWidget {
  const CountsBarChart({super.key, required this.bars, this.height = 200});

  final List<ChartBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bar in bars)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Text(
                      '${bar.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final factor = max == 0 ? 0.0 : bar.value / max;
                          final barHeight = max == 0
                              ? 6.0
                              : (constraints.maxHeight * factor)
                                  .clamp(6.0, constraints.maxHeight);
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: barHeight,
                              width: 28,
                              decoration: BoxDecoration(
                                color: bar.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bar.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.gray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
