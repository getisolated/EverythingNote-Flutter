import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/in_memory_note_repository.dart';
import '../../domain/note.dart';
import '../../domain/note_repository.dart';
import '../../domain/project.dart';

final projectsProvider = Provider<List<Project>>((ref) {
  return const [
    Project(id: 'perso', name: 'Perso'),
    Project(id: 'travail', name: 'Travail'),
    Project(id: 'sandbox', name: 'Sandbox'),
  ];
});

final activeProjectIdProvider = StateProvider<String>((ref) => 'perso');

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  return InMemoryNoteRepository();
});

final notesListProvider = Provider<List<Note>>((ref) {
  final projectId = ref.watch(activeProjectIdProvider);
  final repo = ref.watch(noteRepositoryProvider);
  return repo.listNotes(projectId: projectId);
});

@immutable
class TabRef {
  final String noteId;
  final String title;

  const TabRef({required this.noteId, required this.title});
}

final openTabsProvider = StateProvider<List<TabRef>>((ref) {
  return const [
    TabRef(noteId: 'welcome', title: 'Bienvenue'),
    TabRef(noteId: 'roadmap', title: 'Roadmap'),
  ];
});

final activeTabIndexProvider = StateProvider<int>((ref) => 0);

final activeNoteProvider = Provider<Note?>((ref) {
  final projectId = ref.watch(activeProjectIdProvider);
  final tabs = ref.watch(openTabsProvider);
  final activeIndex = ref.watch(activeTabIndexProvider);

  if (tabs.isEmpty) return null;
  final safeIndex = activeIndex.clamp(0, tabs.length - 1);
  final noteId = tabs[safeIndex].noteId;

  final repo = ref.watch(noteRepositoryProvider);
  return repo.getNote(projectId: projectId, noteId: noteId);
});

final currentEditorDraftProvider = StateProvider<String>((ref) => '');
