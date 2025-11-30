/// Helper functions for file type detection
class FileTypeHelper {
  /// Check if a file path represents an image file
  /// Supports common image extensions: jpg, jpeg, png, webp
  static bool isImageFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');
  }

  /// Check if a file path represents a PDF file
  static bool isPdfFile(String filePath) {
    return filePath.toLowerCase().endsWith('.pdf');
  }

  /// Check if a file path represents a plain text or markdown file
  static bool isTextFile(String filePath) {
    final lowerPath = filePath.toLowerCase();
    return lowerPath.endsWith('.txt') || lowerPath.endsWith('.md');
  }
}

