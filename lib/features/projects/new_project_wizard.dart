
import 'dart:convert';

import 'package:flutter/material.dart';

/// معلومات مجلد الحفظ الذي يختاره المستخدم عبر SAF.
class ProjectSaveLocation {
  final String uri;
  final String name;

  const ProjectSaveLocation({
    required this.uri,
    required this.name,
  });
}

/// معلومات المشروع بعد إنشائه.
class CreatedProjectInfo {
  final String name;
  final String rootUri;
  final String language;
  final String entryFile;
  final bool isFlutterSourceOnly;

  const CreatedProjectInfo({
    required this.name,
    required this.rootUri,
    required this.language,
    required this.entryFile,
    this.isFlutterSourceOnly = false,
  });
}

/// معالج إنشاء المشاريع.
class NewProjectWizard extends StatefulWidget {
  final Future<ProjectSaveLocation?> Function() pickLocation;

  final Future<String> Function(
    String parentUri,
    String directoryName,
  ) createDirectory;

  final Future<void> Function(
    String parentUri,
    String fileName,
    String mimeType,
    List<int> bytes,
  ) writeFile;

  final Future<void> Function(CreatedProjectInfo project) onCreated;

  const NewProjectWizard({
    super.key,
    required this.pickLocation,
    required this.createDirectory,
    required this.writeFile,
    required this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<ProjectSaveLocation?> Function() pickLocation,
    required Future<String> Function(
      String parentUri,
      String directoryName,
    ) createDirectory,
    required Future<void> Function(
      String parentUri,
      String fileName,
      String mimeType,
      List<int> bytes,
    ) writeFile,
    required Future<void> Function(CreatedProjectInfo project) onCreated,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return NewProjectWizard(
          pickLocation: pickLocation,
          createDirectory: createDirectory,
          writeFile: writeFile,
          onCreated: onCreated,
        );
      },
    );
  }

  @override
  State<NewProjectWizard> createState() => _NewProjectWizardState();
}

class _NewProjectWizardState extends State<NewProjectWizard> {
  final PageController _pageController = PageController();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _descriptionController =
      TextEditingController();

  final TextEditingController _packageController = TextEditingController();

  final TextEditingController _versionController =
      TextEditingController(text: '1.0.0');

  final TextEditingController _authorController = TextEditingController();

  final TextEditingController _entryController = TextEditingController();

  final TextEditingController _pythonVersionController =
      TextEditingController(text: '3.11');

  final TextEditingController _nodeVersionController =
      TextEditingController(text: '20');

  final TextEditingController _goModuleController = TextEditingController();

  final TextEditingController _rustEditionController =
      TextEditingController(text: '2021');

  final TextEditingController _sdkConstraintController =
      TextEditingController(text: '>=3.0.0 <4.0.0');

  int _currentStep = 0;

  bool _includeReadme = true;
  bool _includeGitignore = true;
  bool _isCreating = false;
  bool _isPickingLocation = false;

  String? _errorMessage;

  ProjectSaveLocation? _saveLocation;

  String _selectedLanguage = 'Flutter';

  static const List<String> _languages = [
    'Flutter',
    'Dart',
    'Python',
    'JavaScript',
    'TypeScript',
    'Java',
    'Kotlin',
    'Swift',
    'C',
    'C++',
    'HTML',
    'CSS',
    'JSON',
    'SQL',
    'Bash',
    'Go',
    'Rust',
    'PHP',
  ];

  String get _projectName => _nameController.text.trim();

  /// اسم صالح للاستخدام في أسماء الحزم والمجلدات البرمجية.
  ///
  /// نستخدم الشرطة السفلية بدل الشرطة العادية حتى يكون الاسم
  /// مناسبًا أيضًا لأسماء حزم Dart وFlutter.
  String get _safeProjectName {
    var value = _projectName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (value.isEmpty) {
      value = 'my_project';
    }

    if (RegExp(r'^[0-9]').hasMatch(value)) {
      value = 'project_$value';
    }

    return value;
  }

  bool get _isFlutter => _selectedLanguage == 'Flutter';

  /// مسار ملف البداية الحقيقي الذي سيتم إنشاؤه.
  ///
  /// Java يعتمد على اسم الحزمة، لذلك لا نستخدم المسار العام
  /// الموجود في حقل ملف البداية لتحديد موقع Main.java.
  String get _actualEntryFile {
    if (_selectedLanguage == 'Java') {
      final packagePath =
          _packageController.text.trim().replaceAll('.', '/');

      return 'src/$packagePath/Main.java';
    }

    return _entryController.text.trim();
  }

  String get _defaultEntryFile {
    switch (_selectedLanguage) {
      case 'Flutter':
      case 'Dart':
        return 'lib/main.dart';
      case 'Python':
        return 'main.py';
      case 'JavaScript':
        return 'src/index.js';
      case 'TypeScript':
        return 'src/index.ts';
      case 'Java':
        return 'src/Main.java';
      case 'Kotlin':
        return 'src/Main.kt';
      case 'Swift':
        return 'Sources/main.swift';
      case 'C':
        return 'src/main.c';
      case 'C++':
        return 'src/main.cpp';
      case 'HTML':
        return 'index.html';
      case 'CSS':
        return 'styles.css';
      case 'JSON':
        return 'data.json';
      case 'SQL':
        return 'database.sql';
      case 'Bash':
        return 'scripts/main.sh';
      case 'Go':
        return 'main.go';
      case 'Rust':
        return 'src/main.rs';
      case 'PHP':
        return 'public/index.php';
      default:
        return 'README.md';
    }
  }

  @override
  void initState() {
    super.initState();

    _entryController.text = _defaultEntryFile;
  }

  @override
  void dispose() {
    _pageController.dispose();

    _nameController.dispose();
    _descriptionController.dispose();
    _packageController.dispose();
    _versionController.dispose();
    _authorController.dispose();
    _entryController.dispose();
    _pythonVersionController.dispose();
    _nodeVersionController.dispose();
    _goModuleController.dispose();
    _rustEditionController.dispose();
    _sdkConstraintController.dispose();

    super.dispose();
  }

  void _selectLanguage(String language) {
    setState(() {
      _selectedLanguage = language;
      _entryController.text = _defaultEntryFile;
      _errorMessage = null;

      if (language == 'Java') {
        _packageController.text = 'com.example.$_safeProjectName';
      } else {
        _packageController.text = _safeProjectName;
      }

      if (language == 'Go') {
        _goModuleController.text =
            'example.com/$_safeProjectName';
      }
    });
  }

  bool _isValidProjectName(String name) {
    if (name.isEmpty) return false;

    if (name == '.' || name == '..') return false;

    if (name.contains('/') || name.contains('\\')) {
      return false;
    }

    if (name.contains(':')) return false;

    if (name.contains('\u0000')) return false;

    return true;
  }

  bool _isValidRelativePath(String path) {
    if (path.isEmpty) return false;

    if (path.startsWith('/') || path.startsWith('\\')) {
      return false;
    }

    if (path.contains('\\')) return false;

    if (path.contains('\u0000')) return false;

    final segments = path.split('/');

    if (segments.any((segment) {
      return segment.isEmpty ||
          segment == '.' ||
          segment == '..';
    })) {
      return false;
    }

    return true;
  }

  bool _isValidPackageName(String value) {
    if (value.isEmpty) return false;

    final parts = value.split('.');

    if (parts.length < 2) return false;

    final identifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

    return parts.every(identifier.hasMatch);
  }

  bool _isValidVersion(String value) {
    return RegExp(
      r'^\d+\.\d+\.\d+([+-][0-9A-Za-z.-]+)?$',
    ).hasMatch(value);
  }

  bool _isValidSdkConstraint(String value) {
    if (value.isEmpty) return false;

    return RegExp(
      r'^[0-9a-zA-Z.<>=^~+\-\s]+$',
    ).hasMatch(value);
  }

  bool _isValidGoModule(String value) {
    if (value.isEmpty) return false;

    if (value.contains(' ')) return false;

    if (value.startsWith('/') || value.endsWith('/')) {
      return false;
    }

    if (value.contains('\\')) return false;

    return true;
  }

  bool _isValidPythonVersion(String value) {
    return RegExp(r'^\d+\.\d+$').hasMatch(value);
  }

  bool _isValidNodeVersion(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (!_isValidProjectName(_projectName)) {
        _showError('اسم المشروع غير صالح. أدخل اسمًا صحيحًا.');
        return;
      }
    }

    if (_currentStep == 1) {
      _entryController.text = _defaultEntryFile;
    }

    if (_currentStep == 2) {
      // Java يستخدم مسارًا مشتقًا من اسم الحزمة.
      if (_selectedLanguage != 'Java') {
        final entry = _entryController.text.trim();

        if (!_isValidRelativePath(entry)) {
          _showError('مسار ملف البداية غير صالح.');
          return;
        }
      }

      if (!_isValidVersion(_versionController.text.trim())) {
        _showError('صيغة إصدار المشروع غير صحيحة. مثال: 1.0.0');
        return;
      }

      if (_isFlutter || _selectedLanguage == 'Dart') {
        if (!_isValidSdkConstraint(
          _sdkConstraintController.text.trim(),
        )) {
          _showError('قيد إصدار Dart SDK غير صالح.');
          return;
        }
      }

      if (_selectedLanguage == 'Python') {
        if (!_isValidPythonVersion(
          _pythonVersionController.text.trim(),
        )) {
          _showError('أدخل إصدار Python بالشكل 3.11.');
          return;
        }
      }

      if (_selectedLanguage == 'JavaScript' ||
          _selectedLanguage == 'TypeScript') {
        if (!_isValidNodeVersion(
          _nodeVersionController.text.trim(),
        )) {
          _showError('أدخل إصدار Node.js بالشكل 20.');
          return;
        }
      }

      if (_selectedLanguage == 'Java') {
        if (!_isValidPackageName(
          _packageController.text.trim(),
        )) {
          _showError(
            'اسم حزمة Java غير صالح. مثال: com.example.app',
          );
          return;
        }
      }

      if (_selectedLanguage == 'Go') {
        if (!_isValidGoModule(
          _goModuleController.text.trim(),
        )) {
          _showError('اسم Go module غير صالح.');
          return;
        }
      }

      if (_selectedLanguage == 'Rust') {
        if (!['2015', '2018', '2021', '2024'].contains(
          _rustEditionController.text.trim(),
        )) {
          _showError('إصدار Rust edition غير مدعوم.');
          return;
        }
      }

      if (_selectedLanguage == 'PHP') {
        final author = _authorController.text.trim();

        if (author.isNotEmpty &&
            !RegExp(r'^[a-z0-9_.-]+$').hasMatch(author)) {
          _showError('اسم ناشر PHP غير صالح.');
          return;
        }
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });

      await _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      await _chooseLocation();
    }
  }

  Future<void> _previousStep() async {
    if (_currentStep <= 0 || _isCreating || _isPickingLocation) {
      return;
    }

    setState(() {
      _currentStep--;
      _errorMessage = null;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _chooseLocation() async {
    if (_isCreating || _isPickingLocation) return;

    setState(() {
      _isPickingLocation = true;
      _errorMessage = null;
    });

    try {
      final location = await widget.pickLocation();

      if (!mounted || location == null) return;

      setState(() {
        _saveLocation = location;
      });

      await _createProject();
    } catch (e) {
      _showError('تعذر اختيار مكان الحفظ: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLocation = false;
        });
      }
    }
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.dart')) return 'text/x-dart';
    if (lower.endsWith('.py')) return 'text/x-python';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.ts')) return 'application/typescript';
    if (lower.endsWith('.html')) return 'text/html';
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.sql')) return 'application/sql';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.sh')) return 'text/x-shellscript';
    if (lower.endsWith('.java')) return 'text/x-java';
    if (lower.endsWith('.kt')) return 'text/x-kotlin';
    if (lower.endsWith('.swift')) return 'text/x-swift';

    if (lower.endsWith('.c') || lower.endsWith('.h')) {
      return 'text/x-c';
    }

    if (lower.endsWith('.cpp') || lower.endsWith('.hpp')) {
      return 'text/x-c++';
    }

    if (lower.endsWith('.go')) return 'text/x-go';
    if (lower.endsWith('.rs')) return 'text/x-rust';
    if (lower.endsWith('.php')) return 'application/x-httpd-php';
    if (lower.endsWith('.toml')) return 'application/toml';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) {
      return 'application/yaml';
    }

    if (lower.endsWith('.gitignore')) return 'text/plain';

    return 'text/plain';
  }

  Future<void> _writeRelativeFile(
    String rootUri,
    String relativePath,
    String content,
  ) async {
    if (!_isValidRelativePath(relativePath)) {
      throw Exception('مسار ملف غير آمن: $relativePath');
    }

    final segments = relativePath.split('/');

    var currentUri = rootUri;

    for (var i = 0; i < segments.length - 1; i++) {
      currentUri = await widget.createDirectory(
        currentUri,
        segments[i],
      );
    }

    final fileName = segments.last;

    await widget.writeFile(
      currentUri,
      fileName,
      _mimeType(fileName),
      utf8.encode(content),
    );
  }

  Future<void> _createProject() async {
    final location = _saveLocation;

    if (location == null || _isCreating) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final files = _generateProjectFiles();

      // تتم إضافة README من هنا فقط حتى نحترم اختيار المستخدم
      // لجميع اللغات، بما فيها Java.
      if (_includeReadme) {
        files['README.md'] = _generateReadme();
      }

      if (_includeGitignore) {
        files['.gitignore'] = _generateGitignore();
      }

      final rootUri = await widget.createDirectory(
        location.uri,
        _safeProjectName,
      );

      for (final entry in files.entries) {
        await _writeRelativeFile(
          rootUri,
          entry.key,
          entry.value,
        );
      }

      final project = CreatedProjectInfo(
        name: _projectName,
        rootUri: rootUri,
        language: _selectedLanguage,
        entryFile: _actualEntryFile,
        isFlutterSourceOnly: _isFlutter,
      );

      await widget.onCreated(project);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      _showError(
        'فشل إنشاء المشروع: $e\n'
        'قد يكون قد تم إنشاء بعض الملفات قبل حدوث الخطأ.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Map<String, String> _generateProjectFiles() {
    final files = <String, String>{};

    final entry = _selectedLanguage == 'Java'
        ? _actualEntryFile
        : _entryController.text.trim();

    final version = _versionController.text.trim();
    final description = _descriptionController.text.trim();

    final jsonDescription = jsonEncode(description);
    final jsonProjectName = jsonEncode(_projectName);

    switch (_selectedLanguage) {
      case 'Flutter':
        files['pubspec.yaml'] = '''
name: $_safeProjectName
description: ${_yamlString(description.isEmpty ? 'A Flutter application.' : description)}
publish_to: 'none'
version: $version+1

environment:
  sdk: '${_sdkConstraintController.text.trim()}'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
''';

        files[entry] = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: $jsonProjectName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text($jsonProjectName),
      ),
      body: const Center(
        child: Text(
          'Welcome to your new Flutter project!',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
''';
        break;

      case 'Dart':
        files['pubspec.yaml'] = '''
name: $_safeProjectName
description: ${_yamlString(description)}
version: $version

environment:
  sdk: '${_sdkConstraintController.text.trim()}'
''';

        files[entry] = '''
void main() {
  print('Hello from ${_dartString(_projectName)}!');
}
''';
        break;

      case 'Python':
        files['pyproject.toml'] = '''
[project]
name = "$_safeProjectName"
version = "$version"
description = ${_tomlString(description)}
requires-python = ">=${_pythonVersionController.text.trim()}"
''';

        files[entry] = '''
def main():
    print("Hello from ${_pythonString(_projectName)}!")


if __name__ == "__main__":
    main()
''';
        break;

      case 'JavaScript':
        files['package.json'] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "main": ${jsonEncode(entry)},
  "scripts": {
    "start": "node ${_jsonSafeCommand(entry)}"
  },
  "engines": {
    "node": ">=${_nodeVersionController.text.trim()}"
  }
}
''';

        files[entry] = '''
console.log("Hello from ${_jsString(_projectName)}!");
''';
        break;

      case 'TypeScript':
        files['package.json'] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
''';

        files['tsconfig.json'] = '''
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true
  }
}
''';

        files[entry] = '''
function main(): void {
  console.log("Hello from ${_jsString(_projectName)}!");
}

main();
''';
        break;

      case 'Java':
        final packageName = _packageController.text.trim();

        files[entry] = '''
package $packageName;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello from ${_javaString(_projectName)}!");
    }
}
''';
        break;

      case 'Kotlin':
        files[entry] = '''
fun main() {
    println("Hello from ${_kotlinString(_projectName)}!")
}
''';
        break;

      case 'Swift':
        files[entry] = '''
import Foundation

print("Hello from ${_swiftString(_projectName)}!")
''';
        break;

      case 'C':
        files[entry] = '''
#include <stdio.h>

int main(void) {
    printf("Hello from ${_cString(_projectName)}!\\n");
    return 0;
}
''';
        break;

      case 'C++':
        files[entry] = '''
#include <iostream>

int main() {
    std::cout << "Hello from ${_cppString(_projectName)}!" << std::endl;
    return 0;
}
''';
        break;

      case 'HTML':
        files[entry] = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${_htmlEscape(_projectName)}</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <main>
        <h1>Welcome to ${_htmlEscape(_projectName)}</h1>
        <p>Your new HTML project is ready.</p>
    </main>
    <script src="script.js"></script>
</body>
</html>
''';

        files['style.css'] = '''
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 40px;
    background: #f5f5f5;
    color: #222;
}

main {
    max-width: 700px;
    margin: auto;
}
''';

        files['script.js'] = '''
console.log("${_jsString(_projectName)} is ready!");
''';
        break;

      case 'CSS':
        files[entry] = '''
:root {
    font-family: Arial, sans-serif;
    color: #222;
    background: #f5f5f5;
}

body {
    margin: 0;
    padding: 24px;
}

.container {
    max-width: 900px;
    margin: auto;
}
''';
        break;

      case 'JSON':
        files[entry] = '''
{
  "name": ${jsonEncode(_safeProjectName)},
  "version": ${jsonEncode(version)},
  "description": $jsonDescription,
  "created": true
}
''';
        break;

      case 'SQL':
        files[entry] = '''
-- ${_sqlComment(_projectName)} database

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE
);

-- Add your SQL queries below.
''';
        break;

      case 'Bash':
        files[entry] = '''
#!/usr/bin/env bash

set -e

echo '${_shellString('Hello from $_projectName!')}'
''';
        break;

      case 'Go':
        final module = _goModuleController.text.trim();

        files['go.mod'] = '''
module $module

go 1.23
''';

        files[entry] = '''
package main

import "fmt"

func main() {
    fmt.Println("${_goString('Hello from $_projectName!')}")
}
''';
        break;

      case 'Rust':
        files['Cargo.toml'] = '''
[package]
name = "$_safeProjectName"
version = "$version"
edition = "${_rustEditionController.text.trim()}"

[dependencies]
''';

        files[entry] = '''
fn main() {
    println!("Hello from ${_rustString(_projectName)}!");
}
''';
        break;

      case 'PHP':
        final author = _authorController.text.trim().isEmpty
            ? 'app'
            : _authorController.text.trim().toLowerCase();

        files['composer.json'] = '''
{
    "name": ${jsonEncode('$author/$_safeProjectName')},
    "description": $jsonDescription,
    "type": "project",
    "require": {
        "php": ">=8.1"
    }
}
''';

        files[entry] = '''
<?php

echo "${_phpString('Hello from $_projectName!')}";

''';
        break;
    }

    return files;
  }

  String _yamlString(String value) {
    return jsonEncode(value);
  }

  String _tomlString(String value) {
    return jsonEncode(value);
  }

  String _dartString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _jsString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _pythonString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _javaString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _kotlinString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _swiftString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _cString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _cppString(String value) {
    return _cString(value);
  }

  String _goString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _rustString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
  }

  String _phpString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\$', r'\$');
  }

  String _shellString(String value) {
    return value.replaceAll("'", "'\\''");
  }

  String _sqlComment(String value) {
    return value
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _jsonSafeCommand(String value) {
    return value.replaceAll('"', r'\"');
  }

  String _generateReadme() {
    final description = _descriptionController.text.trim();

    final packageInfo = _selectedLanguage == 'Java'
        ? '\n- Java package: `${_packageController.text.trim()}`\n'
        : '';

    return '''
# $_projectName

${description.isEmpty ? 'A new $_selectedLanguage project.' : description}

## Project information

- Language: $_selectedLanguage
- Version: ${_versionController.text.trim()}
- Entry file: $_actualEntryFile
$packageInfo
${_isFlutter ? '''
## Flutter note

This project contains Flutter source files and configuration only.

The Android and iOS native platform scaffolding has not been generated.

A Flutter SDK and the `flutter create` command are required to generate
the complete native project structure.
''' : ''}

## Getting started

Open the project files in your preferred development environment.
''';
  }

  String _generateGitignore() {
    switch (_selectedLanguage) {
      case 'Flutter':
      case 'Dart':
        return '''
.dart_tool/
.packages
.pub-cache/
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
''';

      case 'Python':
        return '''
__pycache__/
*.py[cod]
.venv/
venv/
.env
dist/
build/
''';

      case 'JavaScript':
      case 'TypeScript':
        return '''
node_modules/
dist/
.env
npm-debug.log*
''';

      case 'Java':
        return '''
*.class
build/
target/
.gradle/
.idea/
''';

      case 'Kotlin':
        return '''
*.class
build/
.gradle/
.idea/
''';

      case 'Go':
        return '''
/bin/
/vendor/
*.exe
*.test
''';

      case 'Rust':
        return '''
/target/
''';

      case 'PHP':
        return '''
/vendor/
/.env
''';

      default:
        return '''
.DS_Store
Thumbs.db
.env
''';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: colors.primary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'إنشاء مشروع جديد',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isCreating || _isPickingLocation
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          _buildProgress(colors),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNameStep(),
                _buildLanguageStep(),
                _buildSettingsStep(),
                _buildSummaryStep(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildProgress(ColorScheme colors) {
    const labels = [
      'الاسم',
      'اللغة',
      'الإعدادات',
      'الحفظ',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= _currentStep;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: active
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNameStep() {
    return _stepContent(
      title: 'ما اسم مشروعك؟',
      subtitle: 'أدخل اسمًا واضحًا للمشروع.',
      children: [
        _field(
          controller: _nameController,
          label: 'اسم المشروع',
          hint: 'My Awesome Project',
          icon: Icons.drive_file_rename_outline,
        ),
        const SizedBox(height: 14),
        _field(
          controller: _descriptionController,
          label: 'وصف المشروع (اختياري)',
          hint: 'اكتب وصفًا مختصرًا',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return _stepContent(
      title: 'اختر لغة المشروع',
      subtitle: 'ستظهر إعدادات خاصة باللغة التي تختارها.',
      children: [
        ..._languages.map((language) {
          final selected = language == _selectedLanguage;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: _isCreating || _isPickingLocation
                  ? null
                  : () => _selectLanguage(language),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _languageIcon(language),
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        language,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _languageIcon(String language) {
    switch (language) {
      case 'Flutter':
        return Icons.phone_android;
      case 'Dart':
        return Icons.code;
      case 'Python':
        return Icons.terminal;
      case 'JavaScript':
      case 'TypeScript':
        return Icons.javascript;
      case 'Java':
      case 'Kotlin':
        return Icons.android;
      case 'Swift':
        return Icons.apple;
      case 'HTML':
      case 'CSS':
        return Icons.web;
      case 'SQL':
      case 'JSON':
        return Icons.data_object;
      default:
        return Icons.code;
    }
  }

  Widget _buildSettingsStep() {
    return _stepContent(
      title: 'إعدادات $_selectedLanguage',
      subtitle: 'هذه القيم ستُستخدم عند إنشاء ملفات المشروع.',
      children: [
        if (_selectedLanguage == 'Java')
          _infoCard(
            'سيتم إنشاء ملف البداية تلقائيًا وفق اسم الحزمة:\n'
            '$_actualEntryFile',
          )
        else
          _field(
            controller: _entryController,
            label: 'ملف البداية',
            hint: _defaultEntryFile,
            icon: Icons.insert_drive_file_outlined,
          ),
        const SizedBox(height: 14),
        _field(
          controller: _versionController,
          label: 'إصدار المشروع',
          hint: '1.0.0',
          icon: Icons.tag,
        ),
        if (_selectedLanguage == 'Flutter' ||
            _selectedLanguage == 'Dart') ...[
          const SizedBox(height: 14),
          _field(
            controller: _sdkConstraintController,
            label: 'قيد إصدار Dart SDK',
            hint: '>=3.0.0 <4.0.0',
            icon: Icons.settings_ethernet,
          ),
        ],
        if (_selectedLanguage == 'Flutter') ...[
          const SizedBox(height: 14),
          _infoCard(
            'مشروع Flutter هنا يولّد ملفات المصدر وpubspec.yaml فقط. '
            'لن يتم إنشاء مجلدات Android وiOS الأصلية دون Flutter SDK.',
          ),
        ],
        if (_selectedLanguage == 'Python') ...[
          const SizedBox(height: 14),
          _field(
            controller: _pythonVersionController,
            label: 'أقل إصدار Python مطلوب',
            hint: '3.11',
            icon: Icons.terminal,
          ),
        ],
        if (_selectedLanguage == 'JavaScript' ||
            _selectedLanguage == 'TypeScript') ...[
          const SizedBox(height: 14),
          _field(
            controller: _nodeVersionController,
            label: 'أقل إصدار Node.js مطلوب',
            hint: '20',
            icon: Icons.memory,
          ),
        ],
        if (_selectedLanguage == 'Go') ...[
          const SizedBox(height: 14),
          _field(
            controller: _goModuleController,
            label: 'Go module',
            hint: 'example.com/my_project',
            icon: Icons.account_tree_outlined,
          ),
        ],
        if (_selectedLanguage == 'Rust') ...[
          const SizedBox(height: 14),
          _field(
            controller: _rustEditionController,
            label: 'Rust edition',
            hint: '2021',
            icon: Icons.settings,
          ),
        ],
        if (_selectedLanguage == 'Java') ...[
          const SizedBox(height: 14),
          _field(
            controller: _packageController,
            label: 'اسم حزمة Java',
            hint: 'com.example.myapp',
            icon: Icons.inventory_2_outlined,
          ),
        ],
        if (_selectedLanguage == 'PHP') ...[
          const SizedBox(height: 14),
          _field(
            controller: _authorController,
            label: 'اسم الناشر',
            hint: 'your-vendor',
            icon: Icons.person_outline,
          ),
        ],
        const SizedBox(height: 18),
        _optionTile(
          title: 'إنشاء README.md',
          subtitle: 'ملف يشرح المشروع ومعلوماته.',
          value: _includeReadme,
          onChanged: (value) {
            setState(() => _includeReadme = value);
          },
        ),
        _optionTile(
          title: 'إنشاء .gitignore',
          subtitle: 'تجاهل الملفات غير المطلوبة في Git.',
          value: _includeGitignore,
          onChanged: (value) {
            setState(() => _includeGitignore = value);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryStep() {
    return _stepContent(
      title: 'مكان حفظ المشروع',
      subtitle: 'سيتم إنشاء مجلد باسم المشروع داخل المكان الذي تختاره.',
      children: [
        _infoCard(
          'اسم المشروع: $_projectName\n'
          'اسم المجلد: $_safeProjectName\n'
          'اللغة: $_selectedLanguage\n'
          'ملف البداية: $_actualEntryFile',
        ),
        const SizedBox(height: 14),
        if (_saveLocation != null)
          _infoCard(
            'مكان الحفظ:\n${_saveLocation!.name}',
          )
        else
          _infoCard(
            'عند الضغط على إنشاء المشروع، ستفتح نافذة اختيار مجلد الحفظ.',
          ),
        if (_isFlutter) ...[
          const SizedBox(height: 14),
          _infoCard(
            'تنبيه: مشروع Flutter الناتج يحتوي ملفات المصدر والإعدادات '
            'الأساسية فقط، وليس scaffold أصليًا كاملًا قابلًا للبناء.',
          ),
        ],
      ],
    );
  }

  Widget _stepContent({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isCreating && !_isPickingLocation,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(height: 1.6),
      ),
    );
  }

  Widget _optionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: _isCreating || _isPickingLocation
          ? null
          : onChanged,
    );
  }

  Widget _buildBottomBar() {
    final busy = _isCreating || _isPickingLocation;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Row(
          children: [
            if (_currentStep > 0)
              OutlinedButton.icon(
                onPressed: busy ? null : _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('السابق'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : _currentStep == 3
                      ? _chooseLocation
                      : _nextStep,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _currentStep == 3
                          ? Icons.create_new_folder
                          : Icons.arrow_forward,
                    ),
              label: Text(
                _isCreating
                    ? 'جارٍ الإنشاء...'
                    : _isPickingLocation
                        ? 'جارٍ اختيار المكان...'
                        : _currentStep == 3
                            ? 'اختيار المكان وإنشاء'
                            : 'التالي',
              ),
            ),
          ],
        ),
      ),
    );
  }
}