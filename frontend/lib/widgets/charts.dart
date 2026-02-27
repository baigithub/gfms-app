import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final List<double> data;
  final Color barColor;
  final double height;

  const SimpleBarChart({
    super.key,
    required this.data,
    this.barColor = const Color(0xFF667eea),
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('暂无数据')),
      );
    }

    final maxValue = data.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(data.length, (index) {
          final value = data[index];
          final percentage = maxValue > 0 ? value / maxValue : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 8, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (height - 30) * percentage,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 8, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SimplePieChart extends StatelessWidget {
  final List<PieChartData> data;
  final double size;

  const SimplePieChart({
    super.key,
    required this.data,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('暂无数据')),
      );
    }

    final total = data.fold(0.0, (sum, item) => sum + item.value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: data.map((item) {
              final percentage = total > 0 ? item.value / total : 0.0;
              return Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: size * percentage.clamp(0.3, 1.0),
                    height: size * percentage.clamp(0.3, 1.0),
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.map((item) {
            final percentage = total > 0 ? (item.value / total * 100).toStringAsFixed(0) : '0';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.label} $percentage%',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class PieChartData {
  final String label;
  final double value;
  final Color color;

  const PieChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}
