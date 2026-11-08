class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.changes,
  });

  final String version;
  final List<String> changes;
}
