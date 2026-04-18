import 'package:flutter/material.dart';

class LangBar extends StatelessWidget {
  const LangBar({super.key, required this.languages});

  final List<LangBarSegment> languages;

  @override
  Widget build(BuildContext context) {
    if (languages.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: languages.map((lang) {
            return Expanded(
              flex: (lang.percent * 100).round().clamp(1, 10000),
              child: Container(color: langColor(lang.name)),
            );
          }).toList(),
        ),
      ),
    );
  }

  static Color langColor(String name) {
    return _langColorMap[name.toLowerCase()] ?? _hashColor(name);
  }

  static Color _hashColor(String name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final hue = (hash % 360).abs().toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.62, 0.52).toColor();
  }

  static const _langColorMap = <String, Color>{
    'typescript': Color(0xFF3178C6),
    'javascript': Color(0xFFF7DF1E),
    'python': Color(0xFF3776AB),
    'java': Color(0xFFB07219),
    'kotlin': Color(0xFF7F52FF),
    'dart': Color(0xFF00B4AB),
    'swift': Color(0xFFFA7343),
    'rust': Color(0xFFDEA584),
    'go': Color(0xFF00ADD8),
    'c++': Color(0xFFF34B7D),
    'c#': Color(0xFF178600),
    'c': Color(0xFF555555),
    'ruby': Color(0xFFCC342D),
    'php': Color(0xFF4F5D95),
    'html': Color(0xFFE34C26),
    'css': Color(0xFF563D7C),
    'scss': Color(0xFFCF649A),
    'shell': Color(0xFF89E051),
    'bash': Color(0xFF89E051),
    'sql': Color(0xFFE38C00),
    'json': Color(0xFF292929),
    'yaml': Color(0xFFCB171E),
    'markdown': Color(0xFF083FA1),
    'vue': Color(0xFF41B883),
    'svelte': Color(0xFFFF3E00),
  };
}

class LangBarSegment {
  const LangBarSegment({required this.name, required this.percent});
  final String name;
  final double percent;
}
