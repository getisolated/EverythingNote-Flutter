import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../spotlight/spotlight_overlay.dart';

import '../state/app_providers.dart';

import '../editor/editor_view.dart';

enum SpotlightMode { searchNotes, commands, switchProject }

final spotlightStateProvider =
    StateProvider<SpotlightState>((ref) => const SpotlightState.hidden());

@immutable
class SpotlightState {
  final bool isOpen;
  final SpotlightMode mode;

  const SpotlightState._(this.isOpen, this.mode);

  const SpotlightState.hidden() : this._(false, SpotlightMode.commands);

  const SpotlightState.open(SpotlightMode mode) : this._(true, mode);

  @override
  bool operator ==(Object other) =>
      other is SpotlightState && other.isOpen == isOpen && other.mode == mode;

  @override
  int get hashCode => Object.hash(isOpen, mode);
}

class EditorShellScreen extends ConsumerWidget {
  const EditorShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotlight = ref.watch(spotlightStateProvider);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f1):
            _OpenSpotlightIntent(SpotlightMode.commands),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _OpenSpotlightIntent(SpotlightMode.searchNotes),
        SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _OpenSpotlightIntent(SpotlightMode.switchProject),
        SingleActivator(LogicalKeyboardKey.escape): _CloseSpotlightIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenSpotlightIntent: CallbackAction<_OpenSpotlightIntent>(
            onInvoke: (intent) {
              ref.read(spotlightStateProvider.notifier).state =
                  SpotlightState.open(intent.mode);
              return null;
            },
          ),
          _CloseSpotlightIntent: CallbackAction<_CloseSpotlightIntent>(
            onInvoke: (intent) {
              ref.read(spotlightStateProvider.notifier).state =
                  const SpotlightState.hidden();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Stack(
              children: [
                const _MainLayout(),
                if (spotlight.isOpen)
                  _SpotlightLayer(mode: spotlight.mode),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainLayout extends ConsumerWidget {
  const _MainLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(openTabsProvider);
    final active = ref.watch(activeTabIndexProvider);

    final projectId = ref.watch(activeProjectIdProvider);
    final projectName = ref
        .watch(projectsProvider)
        .firstWhere((p) => p.id == projectId)
        .name;

    return SafeArea(
      child: Column(
        children: [
          _TopTabsBar(
            projectName: projectName,
            tabs: tabs,
            activeIndex: active,
            onSelect: (i) => ref.read(activeTabIndexProvider.notifier).state = i,
            onCloseTab: (i) => _closeTab(ref, i),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: const _NavigationNotes(),
                  ),
                ),
                const Expanded(child: EditorView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closeTab(WidgetRef ref, int index) {
    final tabs = ref.read(openTabsProvider);
    if (tabs.isEmpty) return;

    final newTabs = List<TabRef>.from(tabs)..removeAt(index);
    ref.read(openTabsProvider.notifier).state = newTabs;

    final active = ref.read(activeTabIndexProvider);
    if (newTabs.isEmpty) {
      ref.read(activeTabIndexProvider.notifier).state = 0;
      return;
    }
    if (active >= newTabs.length) {
      ref.read(activeTabIndexProvider.notifier).state = newTabs.length - 1;
    }
  }
}

class _TopTabsBar extends StatelessWidget {
  final String projectName;
  final List<TabRef> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onCloseTab;

  const _TopTabsBar({
    required this.projectName,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onCloseTab,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Chip(
            label: Text(projectName),
            avatar: const Icon(Icons.folder_open, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final isActive = i == activeIndex;
                final tab = tabs[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).iconTheme.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tab.title,
                          style: TextStyle(
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onCloseTab(i),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: tabs.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationNotes extends ConsumerWidget {
  const _NavigationNotes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesListProvider);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Icon(Icons.notes, size: 18),
              SizedBox(width: 8),
              Text('Notes'),
              Spacer(),
              Text('Ctrl+F', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, i) {
              final n = notes[i];
              return ListTile(
                leading: const Icon(Icons.note_outlined),
                title: Text(n.title),
                subtitle: Text(
                  n.content.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openNoteInTab(ref, n.id, n.title),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'F1: commandes · Ctrl+R: projet',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }

  void _openNoteInTab(WidgetRef ref, String noteId, String title) {
    final tabs = ref.read(openTabsProvider);
    final existingIndex = tabs.indexWhere((t) => t.noteId == noteId);
    if (existingIndex >= 0) {
      ref.read(activeTabIndexProvider.notifier).state = existingIndex;
      return;
    }
    final newTabs = List<TabRef>.from(tabs)..add(TabRef(noteId: noteId, title: title));
    ref.read(openTabsProvider.notifier).state = newTabs;
    ref.read(activeTabIndexProvider.notifier).state = newTabs.length - 1;
  }
}

class _SpotlightLayer extends ConsumerWidget {
  final SpotlightMode mode;
  const _SpotlightLayer({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SpotlightState close() => ref.read(spotlightStateProvider.notifier).state =
        const SpotlightState.hidden();

    if (mode == SpotlightMode.searchNotes) {
      final notes = ref.watch(notesListProvider);
      final items = notes
          .map((n) => SpotlightItem(id: n.id, label: n.title, hint: 'Ouvrir la note'))
          .toList();

      return SpotlightOverlay(
        title: 'Rechercher une note',
        items: items,
        onPick: (picked) {
          // ouvrir onglet + activer
          final tabs = ref.read(openTabsProvider);
          final existingIndex = tabs.indexWhere((t) => t.noteId == picked.id);
          if (existingIndex >= 0) {
            ref.read(activeTabIndexProvider.notifier).state = existingIndex;
          } else {
            final newTabs = List<TabRef>.from(tabs)
              ..add(TabRef(noteId: picked.id, title: picked.label));
            ref.read(openTabsProvider.notifier).state = newTabs;
            ref.read(activeTabIndexProvider.notifier).state = newTabs.length - 1;
          }
          close();
        },
        onClose: close,
      );
    }

    if (mode == SpotlightMode.switchProject) {
      final projects = ref.watch(projectsProvider);
      final items = projects
          .map((p) => SpotlightItem(id: p.id, label: p.name, hint: 'Changer de projet'))
          .toList();

      return SpotlightOverlay(
        title: 'Changer de projet',
        items: items,
        onPick: (picked) {
          ref.read(activeProjectIdProvider.notifier).state = picked.id;

          // reset tabs vers 2 notes “par défaut” si dispo
          final notes = ref.read(notesListProvider);
          final firstTwo = notes.take(2).toList();
          final newTabs = firstTwo
              .map((n) => TabRef(noteId: n.id, title: n.title))
              .toList();

          ref.read(openTabsProvider.notifier).state =
              newTabs.isEmpty ? const [] : newTabs;
          ref.read(activeTabIndexProvider.notifier).state = 0;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Projet: ${picked.label}')),
          );
          close();
        },
        onClose: close,
      );
    }

    // Commands mock (visible et utile)
    final items = const [
      SpotlightItem(id: 'new', label: 'New note', hint: 'Créer une note (mock)'),
      SpotlightItem(id: 'rename', label: 'Rename note', hint: 'Renommer (mock)'),
      SpotlightItem(id: 'delete', label: 'Delete note', hint: 'Supprimer (mock)'),
    ];

    return SpotlightOverlay(
      title: 'Commandes',
      items: items,
      onPick: (picked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande: ${picked.label} (mock)')),
        );
        close();
      },
      onClose: close,
    );
  }
}

// Intents
class _OpenSpotlightIntent extends Intent {
  final SpotlightMode mode;
  const _OpenSpotlightIntent(this.mode);
}

class _CloseSpotlightIntent extends Intent {
  const _CloseSpotlightIntent();
}
