import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../spotlight/spotlight_overlay.dart';

import '../state/app_providers.dart';

import '../editor/editor_view.dart';

import '../search/search_engine.dart';

enum SpotlightMode { searchNotes, commands, switchProject }

final spotlightStateProvider = StateProvider<SpotlightState>(
  (ref) => const SpotlightState.hidden(),
);

final spotlightQueryProvider = StateProvider<String>((ref) => '');

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
        SingleActivator(LogicalKeyboardKey.f1): _OpenSpotlightIntent(
          SpotlightMode.commands,
        ),
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _OpenSpotlightIntent(SpotlightMode.searchNotes),
        SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _OpenSpotlightIntent(SpotlightMode.switchProject),
        SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _SaveNowIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CloseSpotlightIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenSpotlightIntent: CallbackAction<_OpenSpotlightIntent>(
            onInvoke: (intent) {
              ref.read(spotlightQueryProvider.notifier).state = '';
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
          _SaveNowIntent: CallbackAction<_SaveNowIntent>(
            onInvoke: (intent) {
              final projectId = ref.read(activeProjectIdProvider);
              final note = ref.read(activeNoteProvider);
              if (note == null) return null;

              final draft = ref.read(currentEditorDraftProvider);
              ref
                  .read(noteRepositoryProvider)
                  .updateNote(
                    projectId: projectId,
                    noteId: note.id,
                    content: draft,
                  );

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sauvegardé ✅')));
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
                if (spotlight.isOpen) _SpotlightLayer(mode: spotlight.mode),
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
            onSelect: (i) =>
                ref.read(activeTabIndexProvider.notifier).state = i,
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
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
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
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
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
    final newTabs = List<TabRef>.from(tabs)
      ..add(TabRef(noteId: noteId, title: title));
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
      final query = ref.watch(spotlightQueryProvider);

      final engine = NotesSearchEngine();
      final results = engine.search(notes, query);

      final items = results
          .map(
            (r) => SpotlightItem(
              id: r.note.id,
              label: r.note.title,
              hint: r.snippet,
            ),
          )
          .toList();

      return SpotlightOverlay(
        title: 'Rechercher une note',
        items: items,
        onQueryChanged: (q) =>
            ref.read(spotlightQueryProvider.notifier).state = q,
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
            ref.read(activeTabIndexProvider.notifier).state =
                newTabs.length - 1;
          }
          // reset query pour la prochaine ouverture
          ref.read(spotlightQueryProvider.notifier).state = '';
          close();
        },
        onClose: () {
          ref.read(spotlightQueryProvider.notifier).state = '';
          close();
        },
      );
    }

    if (mode == SpotlightMode.switchProject) {
      final projects = ref.watch(projectsProvider);
      final items = projects
          .map(
            (p) => SpotlightItem(
              id: p.id,
              label: p.name,
              hint: 'Changer de projet',
            ),
          )
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

          ref.read(openTabsProvider.notifier).state = newTabs.isEmpty
              ? const []
              : newTabs;
          ref.read(activeTabIndexProvider.notifier).state = 0;

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Projet: ${picked.label}')));
          close();
        },
        onClose: close,
      );
    }

    final note = ref.watch(activeNoteProvider);

    final items = [
      const SpotlightItem(id: 'new', label: 'New note', hint: 'Créer une note'),
      SpotlightItem(
        id: 'rename',
        label: 'Rename note',
        hint: note == null ? 'Aucune note ouverte' : 'Renommer la note active',
      ),
      SpotlightItem(
        id: 'delete',
        label: 'Delete note',
        hint: note == null ? 'Aucune note ouverte' : 'Supprimer la note active',
      ),
    ];

    return SpotlightOverlay(
      title: 'Commandes',
      items: items,
      onPick: (picked) async {
        // Capture all provider references before close() disposes the widget
        final projectId = ref.read(activeProjectIdProvider);
        final repo = ref.read(noteRepositoryProvider);
        final tabsNotifier = ref.read(openTabsProvider.notifier);
        final activeIndexNotifier = ref.read(activeTabIndexProvider.notifier);
        final messenger = ScaffoldMessenger.of(context);

        if (picked.id == 'new') {
          close();

          final title = await _promptText(
            context,
            title: 'Nouvelle note',
            hint: 'Titre',
            initialValue: 'Nouvelle note',
          );
          if (title == null || title.trim().isEmpty) return;

          final created = repo.createNote(
            projectId: projectId,
            title: title.trim(),
          );

          // ouvrir onglet + activer
          final tabs = tabsNotifier.state;
          final newTabs = List<TabRef>.from(tabs)
            ..add(TabRef(noteId: created.id, title: created.title));
          tabsNotifier.state = newTabs;
          activeIndexNotifier.state = newTabs.length - 1;

          messenger.showSnackBar(
            SnackBar(content: Text('Note créée: ${created.title}')),
          );
          return;
        }

        if (picked.id == 'rename') {
          if (note == null) return;
          close();

          final newTitle = await _promptText(
            context,
            title: 'Renommer la note',
            hint: 'Nouveau titre',
            initialValue: note.title,
          );
          if (newTitle == null || newTitle.trim().isEmpty) return;

          repo.updateNote(
            projectId: projectId,
            noteId: note.id,
            title: newTitle.trim(),
          );

          // mettre à jour l'onglet correspondant
          final tabs = tabsNotifier.state;
          final idx = tabs.indexWhere((t) => t.noteId == note.id);
          if (idx >= 0) {
            final updated = List<TabRef>.from(tabs);
            updated[idx] = TabRef(noteId: note.id, title: newTitle.trim());
            tabsNotifier.state = updated;
          }

          messenger.showSnackBar(const SnackBar(content: Text('Renommé ✅')));
          return;
        }

        if (picked.id == 'delete') {
          if (note == null) return;
          close();

          final ok = await _confirm(
            context,
            title: 'Supprimer la note ?',
            message: '“${note.title}” sera supprimée.',
          );
          if (!ok) return;

          repo.deleteNote(projectId: projectId, noteId: note.id);

          // fermer tous les onglets sur cette note
          final tabs = tabsNotifier.state;
          final newTabs = tabs.where((t) => t.noteId != note.id).toList();
          tabsNotifier.state = newTabs;

          // ajuster l’onglet actif
          final active = activeIndexNotifier.state;
          if (newTabs.isEmpty) {
            activeIndexNotifier.state = 0;
          } else if (active >= newTabs.length) {
            activeIndexNotifier.state = newTabs.length - 1;
          }

          messenger.showSnackBar(const SnackBar(content: Text('Supprimé 🗑️')));
          return;
        }
      },
      onClose: close,
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
  required String initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return result ?? false;
}

// Intents
class _OpenSpotlightIntent extends Intent {
  final SpotlightMode mode;
  const _OpenSpotlightIntent(this.mode);
}

class _CloseSpotlightIntent extends Intent {
  const _CloseSpotlightIntent();
}

class _SaveNowIntent extends Intent {
  const _SaveNowIntent();
}
