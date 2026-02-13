import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class MarkdownPreview extends StatelessWidget {
  final String data;

  const MarkdownPreview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Markdown(
          data: data.isEmpty ? '_Rien à prévisualiser…_' : data,
          selectable: true,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
