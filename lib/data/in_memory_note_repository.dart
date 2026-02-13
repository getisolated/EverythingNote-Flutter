import '../domain/note.dart';
import '../domain/note_repository.dart';

class InMemoryNoteRepository implements NoteRepository {
  final Map<String, List<Note>> _byProject = {
    'perso': [
      Note(
        id: 'welcome',
        title: 'Bienvenue',
        content: '# SpotNotes\n\nTape du Markdown ici.',
        updatedAt: DateTime.now(),
      ),
      Note(
        id: 'roadmap',
        title: 'Roadmap',
        content: '## Étape 2\n- Notes en mémoire\n- Onglets réels\n- Spotlight ouvre une note',
        updatedAt: DateTime.now(),
      ),
      Note(
        id: 'ideas',
        title: 'Idées',
        content: '- Markdown preview (étape 3)\n- Sync Supabase (plus tard)',
        updatedAt: DateTime.now(),
      ),
    ],
    'travail': [
      Note(
        id: 'meeting',
        title: 'Point client',
        content: '- Export DALI\n- SharePoint\n- Teams invite',
        updatedAt: DateTime.now(),
      ),
      Note(
        id: 'bugs',
        title: 'Bugs',
        content: '- RDLC tableau\n- Ctrl+R override\n',
        updatedAt: DateTime.now(),
      ),
    ],
    'sandbox': [
      Note(
        id: 'scratch',
        title: 'Scratch',
        content: 'Test rapide…',
        updatedAt: DateTime.now(),
      ),
    ],
  };

  @override
  List<Note> listNotes({required String projectId}) {
    final list = List<Note>.from(_byProject[projectId] ?? const []);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Note? getNote({required String projectId, required String noteId}) {
    return (_byProject[projectId] ?? const []).where((n) => n.id == noteId).cast<Note?>().firstWhere(
          (n) => n != null,
          orElse: () => null,
        );
  }

  @override
  Note createNote({required String projectId, required String title}) {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}';
    final note = Note(id: id, title: title, content: '', updatedAt: now);
    final list = _byProject.putIfAbsent(projectId, () => []);
    list.add(note);
    return note;
  }

  @override
  void updateNote({
    required String projectId,
    required String noteId,
    String? title,
    String? content,
  }) {
    final list = _byProject[projectId];
    if (list == null) return;

    final idx = list.indexWhere((n) => n.id == noteId);
    if (idx < 0) return;

    final current = list[idx];
    list[idx] = current.copyWith(
      title: title ?? current.title,
      content: content ?? current.content,
      updatedAt: DateTime.now(),
    );
  }

  @override
  void deleteNote({required String projectId, required String noteId}) {
    final list = _byProject[projectId];
    if (list == null) return;
    list.removeWhere((n) => n.id == noteId);
  }
}
