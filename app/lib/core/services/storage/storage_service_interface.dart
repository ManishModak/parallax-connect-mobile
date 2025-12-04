/// Abstract interface for storage services
abstract class StorageServiceInterface<T> {
  /// Initialize the storage service
  static Future<void> init() async {}

  /// Save an item to storage
  Future<void> saveItem(T item);

  /// Get all items from storage
  List<T> getAllItems();

  /// Clear all items from storage
  Future<void> clearAll();

  /// Get count of items in storage
  int getItemCount();
}
