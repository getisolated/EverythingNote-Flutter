import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SpotlightOverlay extends StatefulWidget {
  final String title;
  final List<SpotlightItem> items;
  final void Function(SpotlightItem picked) onPick;
  final VoidCallback onClose;

  const SpotlightOverlay({
    super.key,
    required this.title,
    required this.items,
    required this.onPick,
    required this.onClose,
  });

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

@immutable
class SpotlightItem {
  final String id;
  final String label;
  final String? hint;

  const SpotlightItem({required this.id, required this.label, this.hint});
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<SpotlightItem> get _filtered {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((it) {
      return it.label.toLowerCase().contains(q) ||
          (it.hint?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _move(int delta) {
    final len = _filtered.length;
    if (len == 0) return;
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, len - 1);
    });
  }

  void _confirm() {
    final list = _filtered;
    if (list.isEmpty) return;
    widget.onPick(list[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final safeIndex = _selectedIndex.clamp(0, (list.isEmpty ? 0 : list.length - 1));

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;

                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    widget.onClose();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    _confirm();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _move(1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _move(-1);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Card(
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt, size: 18),
                            const SizedBox(width: 8),
                            Text(widget.title,
                                style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            Text('Esc',
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: (_) => setState(() {
                            _selectedIndex = 0;
                          }),
                          decoration: const InputDecoration(
                            hintText: 'Tape pour filtrer',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: list.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Aucun résultat.',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: list.length,
                                  itemBuilder: (context, i) {
                                    final it = list[i];
                                    final selected = i == safeIndex;
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: selected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                            : null,
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.subdirectory_arrow_right,
                                          size: 18,
                                          color: selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                        title: Text(it.label),
                                        subtitle: it.hint == null
                                            ? null
                                            : Text(it.hint!),
                                        onTap: () => widget.onPick(it),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '↑ ↓ naviguer, Entrée valider',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
