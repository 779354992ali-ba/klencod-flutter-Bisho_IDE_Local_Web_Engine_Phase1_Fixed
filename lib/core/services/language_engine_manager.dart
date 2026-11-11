enum LanguageEngine {
  webProject,
  webCode,
  jsonViewer,
  unsupported,
}

class LanguageEngineManager {
  const LanguageEngineManager._();

  static LanguageEngine engineForFile(String fileName) {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    switch (extension) {
      case 'html':
      case 'htm':
        return LanguageEngine.webProject;
      case 'js':
      case 'mjs':
      case 'cjs':
      case 'css':
      case 'svg':
        return LanguageEngine.webCode;
      case 'json':
        return LanguageEngine.jsonViewer;
      default:
        return LanguageEngine.unsupported;
    }
  }

  static String? webModeForFile(String fileName) {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    switch (extension) {
      case 'js':
      case 'mjs':
      case 'cjs':
        return 'javascript';
      case 'css':
        return 'css';
      case 'svg':
        return 'svg';
      default:
        return null;
    }
  }
}
