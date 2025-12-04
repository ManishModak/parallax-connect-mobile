import 'package:flutter_test/flutter_test.dart';
import 'package:parallax_connect/features/chat/utils/file_type_helper.dart';

void main() {
  group('FileTypeHelper', () {
    group('isImageFile', () {
      test('should return true for jpg files', () {
        expect(FileTypeHelper.isImageFile('/path/to/image.jpg'), isTrue);
        expect(FileTypeHelper.isImageFile('/path/to/image.JPG'), isTrue);
      });

      test('should return true for jpeg files', () {
        expect(FileTypeHelper.isImageFile('/path/to/photo.jpeg'), isTrue);
        expect(FileTypeHelper.isImageFile('/path/to/photo.JPEG'), isTrue);
      });

      test('should return true for png files', () {
        expect(FileTypeHelper.isImageFile('/path/to/screenshot.png'), isTrue);
        expect(FileTypeHelper.isImageFile('/path/to/screenshot.PNG'), isTrue);
      });

      test('should return true for webp files', () {
        expect(FileTypeHelper.isImageFile('/path/to/image.webp'), isTrue);
        expect(FileTypeHelper.isImageFile('/path/to/image.WEBP'), isTrue);
      });

      test('should return false for non-image files', () {
        expect(FileTypeHelper.isImageFile('/path/to/document.pdf'), isFalse);
        expect(FileTypeHelper.isImageFile('/path/to/file.txt'), isFalse);
        expect(FileTypeHelper.isImageFile('/path/to/video.mp4'), isFalse);
        expect(FileTypeHelper.isImageFile('/path/to/image.gif'), isFalse);
      });
    });

    group('isPdfFile', () {
      test('should return true for pdf files', () {
        expect(FileTypeHelper.isPdfFile('/path/to/document.pdf'), isTrue);
        expect(FileTypeHelper.isPdfFile('/path/to/document.PDF'), isTrue);
      });

      test('should return false for non-pdf files', () {
        expect(FileTypeHelper.isPdfFile('/path/to/image.png'), isFalse);
        expect(FileTypeHelper.isPdfFile('/path/to/file.txt'), isFalse);
        expect(FileTypeHelper.isPdfFile('/path/to/doc.docx'), isFalse);
      });
    });

    group('isTextFile', () {
      test('should return true for txt files', () {
        expect(FileTypeHelper.isTextFile('/path/to/notes.txt'), isTrue);
        expect(FileTypeHelper.isTextFile('/path/to/notes.TXT'), isTrue);
      });

      test('should return true for md files', () {
        expect(FileTypeHelper.isTextFile('/path/to/readme.md'), isTrue);
        expect(FileTypeHelper.isTextFile('/path/to/README.MD'), isTrue);
      });

      test('should return false for non-text files', () {
        expect(FileTypeHelper.isTextFile('/path/to/image.png'), isFalse);
        expect(FileTypeHelper.isTextFile('/path/to/document.pdf'), isFalse);
        expect(FileTypeHelper.isTextFile('/path/to/file.json'), isFalse);
      });
    });
  });
}
