import 'note.dart';

abstract class NoteRepository {
  List<Note> listNotes({required String projectId});
  Note? getNote({required String projectId, required String noteId});
  Note createNote({required String projectId, required String title});
  void updateNote({
    required String projectId,
    required String noteId,
    String? title,
    String? content,
  });
  void deleteNote({required String projectId, required String noteId});
}
