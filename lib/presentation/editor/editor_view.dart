import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_providers.dart';
import 'markdown_preview.dart';

enum MobilePane { edit, preview }

final mobilePaneProvider = StateProvider<MobilePane>((ref) => MobilePane.edit);

class EditorView extends ConsumerStatefulWidget {
  const EditorView({super.key});

  @override
  ConsumerState<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends ConsumerState<EditorView> {
  TextEditingController? _controller;

  String? _boundNoteId;
  String _draft = '';
  String _preview = '';

  Timer? _previewDebounce;
  Timer? _saveDebounce;

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _saveDebounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _bindToNote(String noteId, String content) {
    _previewDebounce?.cancel();
    _saveDebounce?.cancel();
    _controller?.dispose();

    _boundNoteId = noteId;
    _draft = content;
    _preview = content;
    _controller = TextEditingController(text: content);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(currentEditorDraftProvider.notifier).state = content;
    });
  }

  void _onChanged(String value, {required String projectId, required String noteId}) {
    _draft = value;

    ref.read(currentEditorDraftProvider.notifier).state = value;

    // Debounce preview (feel "real-time" but avoids rebuild storm)
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _preview = _draft);
    });

    // Debounce save to repo (avoid updating on every keystroke)
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(noteRepositoryProvider).updateNote(
            projectId: projectId,
            noteId: noteId,
            content: _draft,
          );
      // Refresh UI to reflect updatedAt ordering if you later use it
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(activeNoteProvider);
    final projectId = ref.watch(activeProjectIdProvider);

    if (note == null) {
      return const Center(child: Text('Aucune note ouverte.'));
    }

    if (_boundNoteId != note.id) {
      _bindToNote(note.id, note.content);
    }

    final controller = _controller!;
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      // Desktop / large window: split view
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _EditorBox(
                controller: controller,
                onChanged: (v) => _onChanged(v, projectId: projectId, noteId: note.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MarkdownPreview(data: _preview),
            ),
          ],
        ),
      );
    }

    // Mobile / small: toggle edit / preview
    final pane = ref.watch(mobilePaneProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<MobilePane>(
            segments: const [
              ButtonSegment(value: MobilePane.edit, label: Text('Edit'), icon: Icon(Icons.edit_outlined)),
              ButtonSegment(value: MobilePane.preview, label: Text('Preview'), icon: Icon(Icons.visibility_outlined)),
            ],
            selected: {pane},
            onSelectionChanged: (set) {
              ref.read(mobilePaneProvider.notifier).state = set.first;
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: pane == MobilePane.edit
                ? _EditorBox(
                    controller: controller,
                    onChanged: (v) => _onChanged(v, projectId: projectId, noteId: note.id),
                  )
                : MarkdownPreview(data: _preview),
          ),
        ],
      ),
    );
  }
}

class _EditorBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _EditorBox({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Écris en Markdown…\n\n# Titre\n- Liste\n**gras** `code`',
          ),
        ),
      ),
    );
  }
}
