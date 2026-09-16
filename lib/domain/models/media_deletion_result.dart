class MediaDeletionResult {
  const MediaDeletionResult({
    this.deletedIds = const [],
    this.cancelled = false,
    this.error,
  });
  final List<String> deletedIds;
  final bool cancelled;
  final String? error;
}
