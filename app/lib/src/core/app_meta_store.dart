// Frozen W3 seam. In-memory in S01-30; the `app_meta` table (S01-32) is wired
// in by S01-50.
abstract interface class AppMetaStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
