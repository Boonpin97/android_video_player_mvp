/// Display order for videos in the library. Folders always stay alphabetical.
enum LibrarySort {
  nameAsc('Name A–Z'),
  nameDesc('Name Z–A'),
  dateNewest('Date newest first'),
  dateOldest('Date oldest first');

  const LibrarySort(this.label);
  final String label;
}
