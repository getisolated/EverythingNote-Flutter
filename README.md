# EverythingNote

Application de prise de notes en Markdown, multi-projets, avec un systeme de navigation par "Spotlight" (palette de commandes), construite avec Flutter.

---

## Qu'est-ce que Flutter ?

Flutter est un framework open-source de Google qui permet de creer des applications natives pour plusieurs plateformes (Windows, macOS, Linux, Android, iOS, Web) a partir d'un seul code source ecrit en Dart. L'interface est composee de "widgets" imbriques les uns dans les autres, formant un arbre (widget tree). Chaque element visible a l'ecran (texte, bouton, zone de saisie, mise en page) est un widget.

---

## Technologies et bibliotheques utilisees

| Dependance              | Role                                                                 |
|-------------------------|----------------------------------------------------------------------|
| `flutter`               | Framework UI multi-plateformes                                       |
| `flutter_riverpod`      | Gestion d'etat reactive (state management)                           |
| `go_router`             | Routing declaratif (navigation entre ecrans)                         |
| `flutter_markdown_plus` | Rendu visuel du Markdown (previsualisation en temps reel)             |

### Riverpod en quelques mots

Riverpod est une solution de *state management*. Il permet de definir des "providers" : des unites de donnees ou de logique accessibles de n'importe quel widget, sans les passer manuellement a travers l'arbre de widgets. Quand un provider change, seuls les widgets qui l'observent (`ref.watch`) sont reconstruits. Dans ce projet, Riverpod gere le projet actif, la liste des notes, les onglets ouverts, le brouillon de l'editeur, etc.

---

## Architecture du projet

Le code source se trouve dans `lib/` et suit une architecture en couches inspiree du *Clean Architecture* :

```
lib/
  main.dart                         -- Point d'entree, configuration du routeur et du theme
  domain/                           -- Couche metier (modeles et contrats)
    note.dart                       -- Modele de donnees Note (id, titre, contenu, date)
    project.dart                    -- Modele de donnees Project (id, nom)
    note_repository.dart            -- Interface abstraite du depot de notes (CRUD)
  data/                             -- Couche donnees (implementations concretes)
    in_memory_note_repository.dart  -- Implementation du depot en memoire (RAM)
  presentation/                     -- Couche UI (tout ce que l'utilisateur voit)
    state/
      app_providers.dart            -- Providers Riverpod (etat global de l'application)
    screens/
      editor_shell_screen.dart      -- Ecran principal : barre d'onglets, panneau de notes, Spotlight
    editor/
      editor_view.dart              -- Zone d'edition Markdown avec previsualisation
      markdown_preview.dart         -- Widget de rendu Markdown (lecture seule)
    spotlight/
      spotlight_overlay.dart        -- Overlay "Spotlight" (palette de commandes / recherche)
```

### Couche `domain/`

Contient les modeles de donnees purs et l'interface du depot :

- **`Note`** : objet immutable avec `id`, `title`, `content`, `updatedAt`. Fournit une methode `copyWith` pour creer une copie modifiee (pattern courant en Dart pour l'immutabilite).
- **`Project`** : objet immutable avec `id` et `name`. Represente un espace de travail (ex. "Perso", "Travail").
- **`NoteRepository`** : classe abstraite (interface) definissant les operations CRUD sur les notes (`listNotes`, `getNote`, `createNote`, `updateNote`, `deleteNote`). Aucune implementation concrete ici, cela permet de changer de stockage sans toucher au reste du code.

### Couche `data/`

- **`InMemoryNoteRepository`** : implementation de `NoteRepository` qui stocke les notes dans une `Map<String, List<Note>>` en memoire vive. Les notes sont perdues a chaque arret de l'application. Cette implementation est un point de depart, remplacable par un depot persistant (SQLite, Supabase, fichiers...).

### Couche `presentation/`

#### `state/app_providers.dart`

Contient tous les providers Riverpod de l'application :

| Provider                     | Type                    | Role                                               |
|------------------------------|-------------------------|-----------------------------------------------------|
| `projectsProvider`           | `Provider<List<Project>>` | Liste statique des projets disponibles             |
| `activeProjectIdProvider`    | `StateProvider<String>`   | ID du projet actuellement selectionne              |
| `noteRepositoryProvider`     | `Provider<NoteRepository>`| Instance du depot de notes                         |
| `notesListProvider`          | `Provider<List<Note>>`    | Notes du projet actif, triees par date             |
| `openTabsProvider`           | `StateProvider<List<TabRef>>` | Onglets ouverts dans l'editeur                |
| `activeTabIndexProvider`     | `StateProvider<int>`      | Index de l'onglet actif                            |
| `activeNoteProvider`         | `Provider<Note?>`         | Note correspondant a l'onglet actif (derivee)      |
| `currentEditorDraftProvider` | `StateProvider<String>`   | Contenu brut du brouillon en cours d'edition       |

Les providers derives (`notesListProvider`, `activeNoteProvider`) se recalculent automatiquement quand leurs dependances changent.

#### `screens/editor_shell_screen.dart`

Ecran principal de l'application. Il contient :

- **Raccourcis clavier** : `Ctrl+F` (rechercher), `Ctrl+R` (changer de projet), `F1` (commandes), `Ctrl+S` (sauvegarder), `Echap` (fermer le Spotlight).
- **`_MainLayout`** : disposition principale avec une barre d'onglets en haut, un panneau lateral de navigation des notes (280 px), et l'editeur a droite.
- **`_SpotlightLayer`** : couche superposee qui affiche le Spotlight selon le mode (recherche de notes, changement de projet, commandes). Elle gere aussi la creation, le renommage et la suppression de notes.

#### `editor/editor_view.dart`

Widget a etat (`ConsumerStatefulWidget`) qui gere l'edition d'une note :

- Un `TextEditingController` lie a la note active.
- Un systeme de debounce pour la previsualisation (120 ms) et pour la sauvegarde vers le depot (500 ms), afin d'eviter de reconstruire l'interface a chaque frappe.
- En mode large (>= 900 px) : affichage cote a cote editeur + previsualisation Markdown.
- En mode etroit : basculement editeur / previsualisation via un `SegmentedButton`.

#### `spotlight/spotlight_overlay.dart`

Widget qui affiche une fenetre de recherche/commandes superposee avec fond floute :

- Champ de recherche avec filtrage en temps reel.
- Navigation au clavier (fleches haut/bas, Entree, Echap).
- Chaque element est un `SpotlightItem` avec un `id`, un `label` et un `hint` optionnel.

---

## Point d'entree (`main.dart`)

`main()` lance l'application en l'enveloppant dans un `ProviderScope` (requis par Riverpod). Le routeur (`GoRouter`) definit une seule route `/` qui affiche `EditorShellScreen`. Le theme utilise Material 3 avec une couleur de base teal.

---

## Lancer le projet

Prerequis : Flutter SDK installe (https://docs.flutter.dev/get-started/install).

```bash
# Recuperer les dependances
flutter pub get

# Lancer sur le bureau (Windows/macOS/Linux)
flutter run -d windows   # ou -d macos, -d linux

# Lancer sur un emulateur mobile ou un navigateur
flutter run -d chrome
flutter run               # choisit l'appareil disponible
```

---

## Concepts Flutter utiles pour comprendre le code

- **Widget** : brique de base de l'interface. Peut etre "stateless" (sans etat interne) ou "stateful" (avec etat mutable).
- **`build()`** : methode appelee pour construire l'arbre de widgets. Flutter la rappelle chaque fois que l'etat change.
- **`ConsumerWidget` / `ConsumerStatefulWidget`** : versions Riverpod des widgets Flutter classiques, qui donnent acces a `ref` pour lire ou observer des providers.
- **`ref.watch(provider)`** : observe un provider et reconstruit le widget quand la valeur change.
- **`ref.read(provider)`** : lit la valeur une seule fois, sans observer (utilise dans les callbacks).
- **`StateProvider`** : provider Riverpod contenant une valeur mutable simple.
- **`Provider`** : provider en lecture seule, souvent derive d'autres providers.
- **`@immutable`** : annotation indiquant qu'un objet ne doit pas etre modifie apres creation (on utilise `copyWith` pour creer des variantes).
