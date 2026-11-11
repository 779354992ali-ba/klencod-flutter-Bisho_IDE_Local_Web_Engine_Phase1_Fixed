
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import 'package:highlight/languages/dart.dart' as dart_lang;
import 'package:highlight/languages/python.dart' as python_lang;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/typescript.dart' as ts_lang;
import 'package:highlight/languages/java.dart' as java_lang;
import 'package:highlight/languages/kotlin.dart' as kotlin_lang;
import 'package:highlight/languages/swift.dart' as swift_lang;
import 'package:highlight/languages/cpp.dart' as cpp_lang;
import 'package:highlight/languages/css.dart' as css_lang;
import 'package:highlight/languages/xml.dart' as xml_lang;
import 'package:highlight/languages/json.dart' as json_lang;
import 'package:highlight/languages/sql.dart' as sql_lang;
import 'package:highlight/languages/bash.dart' as bash_lang;
import 'package:highlight/languages/go.dart' as go_lang;
import 'package:highlight/languages/rust.dart' as rust_lang;
import 'package:highlight/languages/php.dart' as php_lang;

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saf/saf.dart';

import 'core/services/saf_file_service.dart';
import 'features/projects/new_project_wizard.dart';
import 'flutter_preview_screen.dart';
import 'html_preview_screen.dart';
import 'web_code_runner_screen.dart';
import 'core/services/language_engine_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BishoIDE());
}

class BishoIDE extends StatelessWidget {
  const BishoIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bisho IDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorTab {
  final String id;
  final CodeController controller;

  String fileName;
  String language;

  String? fileUri;
  String? parentUri;

  bool isSaved;

  EditorTab({
    required this.id,
    required this.controller,
    required this.fileName,
    required this.language,
    this.fileUri,
    this.parentUri,
    this.isSaved = true,
  });
}

/// يمثل عنصرًا داخل شجرة SAF.
class _SafTreeEntry {
  final String uri;
  final String name;
  final String relativePath;
  final String? parentUri;
  final bool isDir;

  const _SafTreeEntry({
    required this.uri,
    required this.name,
    required this.relativePath,
    required this.parentUri,
    required this.isDir,
  });
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  static const String _savedDirectoryUriKey =
      'bisho_selected_directory_uri';

  static const String _savedDirectoryNameKey =
      'bisho_selected_directory_name';

  final Saf saf = Saf();
  final SafFileService safFiles = SafFileService();

  final Map<String, dynamic> languages = {
    'Dart': dart_lang.dart,
    'Python': python_lang.python,
    'JavaScript': js_lang.javascript,
    'TypeScript': ts_lang.typescript,
    'Java': java_lang.java,
    'Kotlin': kotlin_lang.kotlin,
    'Swift': swift_lang.swift,
    'C': cpp_lang.cpp,
    'C++': cpp_lang.cpp,
    'CSS': css_lang.css,
    'HTML': xml_lang.xml,
    'XML': xml_lang.xml,
    'JSON': json_lang.json,
    'SQL': sql_lang.sql,
    'Bash': bash_lang.bash,
    'Go': go_lang.go,
    'Rust': rust_lang.rust,
    'PHP': php_lang.php,
  };

  final Map<String, String> extensions = {
    'Dart': 'dart',
    'Python': 'py',
    'JavaScript': 'js',
    'TypeScript': 'ts',
    'Java': 'java',
    'Kotlin': 'kt',
    'Swift': 'swift',
    'C': 'c',
    'C++': 'cpp',
    'CSS': 'css',
    'HTML': 'html',
    'XML': 'xml',
    'JSON': 'json',
    'SQL': 'sql',
    'Bash': 'sh',
    'Go': 'go',
    'Rust': 'rs',
    'PHP': 'php',
  };

  final List<EditorTab> tabs = [];

  int activeIndex = 0;
  int nextTabId = 1;
  int _explorerRevision = 0;

  String status = 'جاهز';

  String? projectUri;
  String projectName = 'لا يوجد مشروع';

  String? selectedDirectoryUri;
  String selectedDirectoryName = '';

  bool isRestoring = false;
  bool explorerVisible = true;

  EditorTab get activeTab => tabs[activeIndex];

  String? get creationDirectoryUri {
    return selectedDirectoryUri ?? projectUri;
  }

  String get creationDirectoryName {
    if (selectedDirectoryUri == null) {
      return projectName;
    }

    return selectedDirectoryName;
  }

  @override
  void initState() {
    super.initState();
    restoreTabs();
  }

  String createId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${nextTabId++}';
  }

  EditorTab createTab({
    String fileName = 'untitled.dart',
    String language = 'Dart',
    String? code,
    String? fileUri,
    String? parentUri,
    bool isSaved = false,
  }) {
    final controller = CodeController(
      text: code ??
          '// Welcome to Bisho IDE\n\nvoid main() {\n  print("Hello World");\n}',
      language: languages[language] ?? languages['Dart'],
    );

    final tab = EditorTab(
      id: createId(),
      controller: controller,
      fileName: fileName,
      language: language,
      fileUri: fileUri,
      parentUri: parentUri,
      isSaved: isSaved,
    );

    controller.addListener(() {
      if (!mounted || isRestoring) return;

      setState(() {
        tab.isSaved = false;
        status = 'تعديلات جديدة';
      });
    });

    return tab;
  }

  Future<void> _saveSelectedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    if (selectedDirectoryUri == null ||
        selectedDirectoryUri!.isEmpty) {
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      return;
    }

    await prefs.setString(
      _savedDirectoryUriKey,
      selectedDirectoryUri!,
    );

    await prefs.setString(
      _savedDirectoryNameKey,
      selectedDirectoryName,
    );
  }

  Future<void> _clearSavedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_savedDirectoryUriKey);
    await prefs.remove(_savedDirectoryNameKey);
  }

  Future<void> selectCreationDirectory(
    String directoryUri,
    String directoryName,
  ) async {
    if (projectUri == null) return;

    try {
      final directory = await safFiles.getItem(directoryUri);

      if (directory == null || !directory.isDir) {
        showMessage('هذا المجلد غير متاح');
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        showMessage('تعذر الوصول إلى جذر المشروع');
        return;
      }

      final tree = await collectSubtree(root);

      final isInsideProject = tree.any(
        (entry) =>
            entry.uri == directoryUri &&
            entry.isDir,
      );

      if (!isInsideProject) {
        showMessage('المجلد ليس داخل المشروع المفتوح');
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = directory.uri;
        selectedDirectoryName = directory.name.isNotEmpty
            ? directory.name
            : directoryName;
        status = 'مجلد العمل: $selectedDirectoryName';
      });

      await _saveSelectedDirectoryState();

      if (!mounted) return;

      showMessage(
        'تم حفظ "$selectedDirectoryName" كمجلد عمل',
      );
    } catch (e) {
      showMessage('تعذر تحديد مجلد العمل: $e');
    }
  }

  Future<void> resetCreationDirectory() async {
    if (projectUri == null) return;

    try {
      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';
        status = 'مجلد العمل: جذر المشروع';
      });

      await _clearSavedDirectoryState();

      if (!mounted) return;

      showMessage('تمت العودة إلى جذر المشروع');
    } catch (e) {
      showMessage('تعذر تغيير مجلد العمل: $e');
    }
  }

  void refreshExplorer() {
    if (!mounted) return;

    setState(() {
      _explorerRevision++;
      status = 'تم تحديث المستكشف';
    });
  }

  Future<void> _restoreSelectedDirectory(
    SharedPreferences prefs,
  ) async {
    selectedDirectoryUri = null;
    selectedDirectoryName = '';

    try {
      if (projectUri == null || projectUri!.isEmpty) {
        await _clearSavedDirectoryState();
        return;
      }

      final savedUri = prefs.getString(_savedDirectoryUriKey);

      if (savedUri == null || savedUri.isEmpty) {
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        await _clearSavedDirectoryState();
        return;
      }

      final tree = await collectSubtree(root);

      _SafTreeEntry? matchingDirectory;

      for (final entry in tree) {
        if (entry.uri == savedUri && entry.isDir) {
          matchingDirectory = entry;
          break;
        }
      }

      if (matchingDirectory == null) {
        await _clearSavedDirectoryState();
        return;
      }

      selectedDirectoryUri = matchingDirectory.uri;
      selectedDirectoryName = matchingDirectory.name;

      await _saveSelectedDirectoryState();
    } catch (_) {
      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      try {
        await _clearSavedDirectoryState();
      } catch (_) {}
    }
  }

  Future<void> restoreTabs() async {
    isRestoring = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTabs = prefs.getString('bisho_tabs');
      final savedIndex = prefs.getInt('bisho_active_index') ?? 0;

      final savedProjectUri =
          prefs.getString('bisho_project_uri');

      final savedProjectName =
          prefs.getString('bisho_project_name') ??
              'لا يوجد مشروع';

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      if (savedProjectUri != null &&
          savedProjectUri.isNotEmpty) {
        try {
          final permissions =
              await safFiles.getPersistedPermissions();

          final matchingPermission = permissions.where(
            (permission) =>
                permission.uri == savedProjectUri &&
                permission.read &&
                permission.write,
          );

          if (matchingPermission.isNotEmpty) {
            final root = await safFiles.getItem(savedProjectUri);

            if (root != null && root.isDir) {
              projectUri = savedProjectUri;
              projectName = savedProjectName;

              await _restoreSelectedDirectory(prefs);
            } else {
              await prefs.remove('bisho_project_uri');
              await prefs.remove('bisho_project_name');

              await _clearSavedDirectoryState();
            }
          } else {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          }
        } catch (_) {
          projectUri = null;
          projectName = 'لا يوجد مشروع';

          selectedDirectoryUri = null;
          selectedDirectoryName = '';

          try {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          } catch (_) {}
        }
      } else {
        await _clearSavedDirectoryState();
      }

      if (savedTabs != null) {
        final List<dynamic> data = jsonDecode(savedTabs);

        for (final item in data) {
          final language =
              item['language'] as String? ?? 'Dart';

          final safeLanguage =
              languages.containsKey(language)
                  ? language
                  : 'Dart';

          tabs.add(
            createTab(
              fileName:
                  item['fileName'] as String? ?? 'untitled.dart',
              language: safeLanguage,
              code: item['code'] as String? ?? '',
              fileUri: item['fileUri'] as String?,
              parentUri: item['parentUri'] as String?,
              isSaved: true,
            ),
          );
        }
      } else {
        final oldCode = prefs.getString('bisho_code');

        final oldName =
            prefs.getString('bisho_filename') ?? 'main.dart';

        final oldLanguage =
            prefs.getString('bisho_language') ?? 'Dart';

        final safeLanguage =
            languages.containsKey(oldLanguage)
                ? oldLanguage
                : 'Dart';

        tabs.add(
          createTab(
            fileName: oldName,
            language: safeLanguage,
            code: oldCode,
            isSaved: true,
          ),
        );
      }

      if (tabs.isEmpty) {
        tabs.add(createTab());
      }

      activeIndex =
          savedIndex.clamp(0, tabs.length - 1).toInt();
    } catch (e) {
      for (final tab in tabs) {
        tab.controller.dispose();
      }

      tabs.clear();
      tabs.add(createTab());

      activeIndex = 0;

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';
    }

    isRestoring = false;

    if (mounted) {
      setState(() {
        status = projectUri != null
            ? 'تم استعادة المشروع والملفات'
            : 'تم استعادة الملفات - افتح مجلد المشروع';
      });
    }
  }

  Future<void> saveTabStateSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final data = tabs.map((tab) {
        return {
          'fileName': tab.fileName,
          'language': tab.language,
          'code': tab.controller.text,
          'fileUri': tab.fileUri,
          'parentUri': tab.parentUri,
        };
      }).toList();

      await prefs.setString('bisho_tabs', jsonEncode(data));
      await prefs.setInt('bisho_active_index', activeIndex);
    } catch (_) {}
  }

  String _mimeType(String name) {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';

    const types = {
      'dart': 'text/plain',
      'py': 'text/x-python',
      'js': 'text/javascript',
      'ts': 'text/typescript',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'json': 'application/json',
      'xml': 'application/xml',
      'java': 'text/x-java-source',
      'kt': 'text/plain',
      'php': 'text/plain',
      'sql': 'text/plain',
      'sh': 'text/plain',
      'txt': 'text/plain',
    };

    return types[ext] ?? 'application/octet-stream';
  }

  Future<bool> saveTabToSAF(EditorTab tab) async {
    if (tab.parentUri == null || tab.parentUri!.isEmpty) {
      return false;
    }

    final bytes = Uint8List.fromList(
      utf8.encode(tab.controller.text),
    );

    final document = await safFiles.saveFile(
      parentUri: tab.parentUri!,
      fileName: tab.fileName,
      mimeType: _mimeType(tab.fileName),
      bytes: bytes,
      overwrite: true,
    );

    tab.fileUri = document.uri;
    tab.isSaved = true;

    return true;
  }

  Future<void> saveAllTabs() async {
    try {
      int savedCount = 0;
      int skippedCount = 0;

      for (final tab in tabs) {
        if (tab.parentUri == null) {
          skippedCount++;
          continue;
        }

        await saveTabToSAF(tab);
        savedCount++;
      }

      await saveTabStateSilently();

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ $savedCount ملف';
      });

      if (skippedCount > 0) {
        showMessage(
          'تم حفظ $savedCount ملف. '
          '$skippedCount ملف يحتاج إلى تصدير منفصل.',
        );
      } else {
        showMessage('تم حفظ جميع الملفات');
      }
    } catch (e) {
      showMessage('تعذر حفظ بعض الملفات: $e');
    }
  }

  void createNewTab() {
    setState(() {
      tabs.add(createTab());
      activeIndex = tabs.length - 1;
      status = 'تم إنشاء ملف جديد';
    });

    saveTabStateSilently();
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    setState(() {
      activeIndex = index;
      status = 'تم فتح ${activeTab.fileName}';
    });
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;

    final tab = tabs[index];

    if (!tab.isSaved) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إغلاق الملف؟'),
          content: Text(
            'الملف ${tab.fileName} يحتوي على تعديلات غير محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق بدون حفظ'),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;
    }

    setState(() {
      tab.controller.dispose();
      tabs.removeAt(index);

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else if (activeIndex > index) {
        activeIndex--;
      } else if (activeIndex >= tabs.length) {
        activeIndex = tabs.length - 1;
      }
    });

    await saveTabStateSilently();
  }

  String detectLanguage(String extension) {
    const map = {
      'dart': 'Dart',
      'py': 'Python',
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'java': 'Java',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'c': 'C',
      'h': 'C',
      'cpp': 'C++',
      'cc': 'C++',
      'css': 'CSS',
      'html': 'HTML',
      'htm': 'HTML',
      'xml': 'XML',
      'json': 'JSON',
      'sql': 'SQL',
      'sh': 'Bash',
      'go': 'Go',
      'rs': 'Rust',
      'php': 'PHP',
    };

    return map[extension.toLowerCase()] ?? 'Dart';
  }

  Future<void> openFile() async {
    try {
      final file = await saf.pickFile(
        persistablePermission: true,
      );

      if (file == null) return;

      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: null,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح الملف';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر فتح الملف: $e');
    }
  }

  Future<void> openProjectFolder() async {
    try {
      final directory = await safFiles.pickProjectFolder();

      if (directory == null) return;

      if (projectUri == directory.uri) {
        refreshExplorer();
        showMessage('هذا المشروع مفتوح بالفعل');
        return;
      }

      final projectTabs = tabs
          .where((tab) =>
              tab.parentUri != null && tab.parentUri!.isNotEmpty)
          .toList();

      final unsavedCount =
          projectTabs.where((tab) => !tab.isSaved).length;

      if (projectUri != null && projectTabs.isNotEmpty) {
        final message = unsavedCount > 0
            ? 'يوجد $unsavedCount ملف غير محفوظ في المشروع الحالي.\n\n'
                'ستبقى التبويبات القديمة مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.'
            : 'ستبقى تبويبات المشروع الحالي مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.';

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تغيير المشروع؟'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('متابعة'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;
      }

      await saveTabStateSilently();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('bisho_project_uri', directory.uri);
      await prefs.setString('bisho_project_name', directory.name);

      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);

      if (!mounted) return;

      setState(() {
        projectUri = directory.uri;
        projectName = directory.name;

        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        explorerVisible = true;
        _explorerRevision++;
        status = 'تم فتح المشروع عبر SAF';
      });

      showMessage('تم فتح مجلد المشروع');
    } catch (e) {
      showMessage('تعذر فتح المجلد: $e');
    }
  }

  /// إنشاء مشروع جديد باستخدام معالج المشاريع وSAF.
  Future<void> createNewProject() async {
    bool firstDirectory = true;

    try {
      await NewProjectWizard.show(
        context,
        pickLocation: () async {
          final folder = await safFiles.pickProjectFolder();

          if (folder == null) return null;

          return ProjectSaveLocation(
            uri: folder.uri,
            name: folder.name,
          );
        },
        createDirectory: (parentUri, directoryName) async {
          final existing = await safFiles.findChild(
            parentUri: parentUri,
            name: directoryName,
          );

          if (firstDirectory) {
            firstDirectory = false;

            if (existing != null) {
              throw Exception(
                'يوجد عنصر بالاسم "$directoryName" '
                'في مجلد الحفظ. اختر اسمًا آخر أو مجلدًا مختلفًا.',
              );
            }
          } else {
            if (existing != null) {
              if (existing.isDir) {
                return existing.uri;
              }

              throw Exception(
                'يوجد ملف بالاسم "$directoryName" '
                'ولا يمكن استخدامه كمجلد.',
              );
            }
          }

          final folder = await safFiles.createFolder(
            parentUri: parentUri,
            folderName: directoryName,
          );

          return folder.uri;
        },
        writeFile: (
          parentUri,
          fileName,
          mimeType,
          bytes,
        ) async {
          await safFiles.saveFile(
            parentUri: parentUri,
            fileName: fileName,
            mimeType: mimeType,
            bytes: Uint8List.fromList(bytes),
            overwrite: false,
          );
        },
        onCreated: (project) async {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(
            'bisho_project_uri',
            project.rootUri,
          );

          await prefs.setString(
            'bisho_project_name',
            project.name,
          );

          await prefs.remove(_savedDirectoryUriKey);
          await prefs.remove(_savedDirectoryNameKey);

          if (!mounted) return;

          setState(() {
            projectUri = project.rootUri;
            projectName = project.name;

            selectedDirectoryUri = null;
            selectedDirectoryName = '';

            explorerVisible = true;
            _explorerRevision++;

            status = 'تم إنشاء المشروع ${project.name}';
          });

          // البحث عن ملف البداية داخل المشروع.
          try {
            final segments = project.entryFile
                .split('/')
                .where((segment) => segment.isNotEmpty)
                .toList();

            var currentUri = project.rootUri;
            SafDocumentFile? entryFile;
            var entryParentUri = currentUri;

            for (var i = 0; i < segments.length; i++) {
              final found = await safFiles.findChild(
                parentUri: currentUri,
                name: segments[i],
              );

              if (found == null) {
                break;
              }

              if (i == segments.length - 1) {
                if (!found.isDir) {
                  entryFile = found;
                  entryParentUri = currentUri;
                }
              } else {
                if (!found.isDir) {
                  break;
                }

                currentUri = found.uri;
              }
            }

            if (!mounted) return;

            if (entryFile != null) {
              await openProjectFile(
                entryFile,
                entryParentUri,
              );
            } else {
              showMessage(
                'تم إنشاء المشروع، لكن تعذر العثور على ملف البداية.',
              );
            }
          } catch (e) {
            showMessage(
              'تم إنشاء المشروع، لكن تعذر فتح ملف البداية: $e',
            );
          }

          await saveTabStateSilently();

          if (!mounted) return;

          if (project.isFlutterSourceOnly) {
            showMessage(
              'تم إنشاء ملفات مصدر Flutter. '
              'يلزم Flutter SDK لإنشاء ملفات البناء الأصلية.',
            );
          } else {
            showMessage(
              'تم إنشاء المشروع وفتح ملف البداية بنجاح',
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      showMessage('تعذر إنشاء المشروع: $e');
    }
  }

  Future<void> openProjectFile(
    SafDocumentFile file,
    String parentUri,
  ) async {
    try {
      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: parentUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح ${file.name}';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر قراءة الملف: $e');
    }
  }

  Future<void> createProjectFile() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء ملف داخل $targetName',
      'مثال: main.dart',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final fileName = name.trim();

    if (fileName.contains('/') || fileName.contains('\\')) {
      showMessage('اكتب اسم ملف فقط');
      return;
    }

    try {
      final document = await safFiles.saveFile(
        parentUri: targetUri,
        fileName: fileName,
        mimeType: _mimeType(fileName),
        bytes: Uint8List(0),
        overwrite: false,
      );

      final language = detectLanguage(
        fileName.contains('.') ? fileName.split('.').last : '',
      );

      if (!mounted) return;

      setState(() {
        tabs.add(
          createTab(
            fileName: fileName,
            language: language,
            code: '',
            fileUri: document.uri,
            parentUri: targetUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        _explorerRevision++;
        status = 'تم إنشاء الملف داخل $targetName';
      });

      await saveTabStateSilently();
      showMessage('تم إنشاء الملف داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء الملف: $e');
    }
  }

  Future<void> createProjectFolder() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء مجلد داخل $targetName',
      'اسم المجلد',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final folderName = name.trim();

    if (folderName.contains('/') || folderName.contains('\\')) {
      showMessage('اكتب اسم مجلد فقط');
      return;
    }

    try {
      await safFiles.createFolder(
        parentUri: targetUri,
        folderName: folderName,
      );

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم إنشاء المجلد داخل $targetName';
      });

      showMessage('تم إنشاء المجلد داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء المجلد: $e');
    }
  }

  Future<String?> askName(String title, String hint) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<List<_SafTreeEntry>> collectSubtree(
    SafDocumentFile root,
  ) async {
    final result = <_SafTreeEntry>[];
    final visited = <String>{};

    Future<void> visit(
      SafDocumentFile item, {
      required String relativePath,
      required String? parentUri,
    }) async {
      if (!visited.add(item.uri)) return;

      result.add(
        _SafTreeEntry(
          uri: item.uri,
          name: item.name,
          relativePath: relativePath,
          parentUri: parentUri,
          isDir: item.isDir,
        ),
      );

      if (!item.isDir) return;

      final children = await safFiles.listDirectory(item.uri);

      for (final child in children) {
        final childPath = relativePath.isEmpty
            ? child.name
            : '$relativePath/${child.name}';

        await visit(
          child,
          relativePath: childPath,
          parentUri: item.uri,
        );
      }
    }

    await visit(
      root,
      relativePath: '',
      parentUri: null,
    );

    return result;
  }

  Future<void> renameEntity(SafDocumentFile entity) async {
    final name = await askName('إعادة تسمية', entity.name);

    if (name == null || name.trim().isEmpty || !mounted) return;

    final newName = name.trim();

    if (newName.contains('/') || newName.contains('\\')) {
      showMessage('اكتب اسمًا فقط');
      return;
    }

    if (newName == entity.name) return;

    try {
      final oldTree = await collectSubtree(entity);

      final renamed = await safFiles.renameItem(
        uri: entity.uri,
        newName: newName,
      );

      if (entity.isDir) {
        final newTree = await collectSubtree(renamed);

        final oldByUri = <String, _SafTreeEntry>{
          for (final item in oldTree) item.uri: item,
        };

        final newByPath = <String, _SafTreeEntry>{
          for (final item in newTree) item.relativePath: item,
        };

        if (selectedDirectoryUri != null) {
          final selectedEntry = oldByUri[selectedDirectoryUri];

          if (selectedEntry != null) {
            final newSelectedEntry =
                newByPath[selectedEntry.relativePath];

            if (newSelectedEntry != null) {
              selectedDirectoryUri = newSelectedEntry.uri;
              selectedDirectoryName = newSelectedEntry.name;
            }
          }
        }

        for (final tab in tabs) {
          final oldFileEntry = tab.fileUri == null
              ? null
              : oldByUri[tab.fileUri];

          if (oldFileEntry != null) {
            final newFileEntry =
                newByPath[oldFileEntry.relativePath];

            if (newFileEntry != null) {
              tab.fileUri = newFileEntry.uri;
              tab.fileName = newFileEntry.name;
            }
          }

          if (tab.parentUri != null) {
            final oldParentEntry = oldByUri[tab.parentUri];

            if (oldParentEntry != null) {
              final newParentEntry =
                  newByPath[oldParentEntry.relativePath];

              if (newParentEntry != null) {
                tab.parentUri = newParentEntry.uri;
              }
            }
          }
        }
      } else {
        for (final tab in tabs) {
          if (tab.fileUri == entity.uri) {
            tab.fileUri = renamed.uri;
            tab.fileName = renamed.name;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم تغيير الاسم';
      });

      await _saveSelectedDirectoryState();
      await saveTabStateSilently();

      if (!mounted) return;

      showMessage('تم تغيير الاسم وتحديث البيانات المحفوظة');
    } catch (e) {
      refreshExplorer();
      showMessage('تعذرت إعادة التسمية أو تحديث التبويبات: $e');
    }
  }

  Future<void> deleteEntity(SafDocumentFile entity) async {
    try {
      final subtree = await collectSubtree(entity);

      final deletedUris = subtree.map((item) => item.uri).toSet();

      final affectedTabs = tabs.where((tab) {
        final fileIsInside = tab.fileUri != null &&
            deletedUris.contains(tab.fileUri);

        final parentIsInside = tab.parentUri != null &&
            deletedUris.contains(tab.parentUri);

        return fileIsInside || parentIsInside;
      }).toList();

      final unsavedCount =
          affectedTabs.where((tab) => !tab.isSaved).length;

      final message = unsavedCount > 0
          ? 'هل تريد حذف ${entity.name}؟\n\n'
              'يوجد $unsavedCount ملف مفتوح يحتوي على تعديلات غير محفوظة. '
              'سيتم إغلاق التبويبات التابعة لهذا العنصر وفقدان تعديلاتها.'
          : 'هل تريد حذف ${entity.name}؟';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final activeId =
          tabs.isNotEmpty ? activeTab.id : null;
      final oldActiveIndex = activeIndex;

      await safFiles.deleteItem(entity.uri);

      final selectedDirectoryWasDeleted =
          selectedDirectoryUri != null &&
          deletedUris.contains(selectedDirectoryUri);

      if (selectedDirectoryWasDeleted) {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        await _clearSavedDirectoryState();
      }

      for (final tab in affectedTabs) {
        tab.controller.dispose();
      }

      tabs.removeWhere((tab) => affectedTabs.contains(tab));

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else {
        final preservedIndex = activeId == null
            ? -1
            : tabs.indexWhere((tab) => tab.id == activeId);

        if (preservedIndex != -1) {
          activeIndex = preservedIndex;
        } else {
          activeIndex = oldActiveIndex
              .clamp(0, tabs.length - 1)
              .toInt();
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم حذف العنصر';
      });

      await saveTabStateSilently();

      if (!mounted) return;

      showMessage(
        selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم الحذف وإغلاق التبويبات التابعة',
      );
    } catch (e) {
      refreshExplorer();
      showMessage('تعذر حذف العنصر: $e');
    }
  }

  Future<void> saveCurrentToDisk() async {
    final tab = activeTab;

    if (tab.parentUri == null) {
      showMessage('هذا الملف مستقل. استخدم تصدير لحفظ التعديلات.');
      return;
    }

    try {
      await saveTabToSAF(tab);

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ ${tab.fileName}';
      });

      await saveTabStateSilently();
      showMessage('تم حفظ الملف');
    } catch (e) {
      showMessage('تعذر حفظ الملف: $e');
    }
  }

  Future<void> exportFile() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(activeTab.controller.text),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير الملف',
        fileName: activeTab.fileName,
        bytes: bytes,
      );

      if (path != null && mounted) {
        setState(() {
          activeTab.isSaved = true;
          status = 'تم التصدير';
        });

        await saveTabStateSilently();
        showMessage('تم تصدير الملف');
      }
    } catch (e) {
      showMessage('تعذر تصدير الملف: $e');
    }
  }

  void changeLanguage(String? language) {
    if (language == null) return;

    setState(() {
      activeTab.language = language;
      activeTab.controller.language = languages[language];

      final parts = activeTab.fileName.split('.');
      final baseName = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('.')
          : activeTab.fileName;

      activeTab.fileName =
          '$baseName.${extensions[language] ?? 'txt'}';

      activeTab.isSaved = false;
      status = 'تم تغيير اللغة';
    });

    saveTabStateSilently();
  }

  Future<void> searchCode() async {
    final controller = TextEditingController();

    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('البحث في الكود'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اكتب النص للبحث',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('بحث'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (query == null || query.isEmpty) return;

    final index = activeTab.controller.text.indexOf(query);

    if (index == -1) {
      showMessage('لم يتم العثور على النص');
      return;
    }

    activeTab.controller.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + query.length,
    );

    showMessage('تم العثور على النص');
  }

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: activeTab.controller.text),
    );

    showMessage('تم نسخ الكود');
  }

  void openFlutterPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlutterPreviewScreen(
          projectName: projectName,
        ),
      ),
    );
  }

  Future<void> openLanguagePreview() async {
    final tab = activeTab;
    final engine = LanguageEngineManager.engineForFile(tab.fileName);

    switch (engine) {
      case LanguageEngine.webProject:
        if (projectUri == null || projectUri!.isEmpty) {
          showMessage(
            'افتح مجلد المشروع أولاً لمعاينة ملفات HTML وموارد المشروع',
          );
          return;
        }

        if (tab.fileUri == null || tab.fileUri!.isEmpty) {
          showMessage(
            'احفظ ملف HTML داخل المشروع أو افتحه من مستكشف المشروع أولاً',
          );
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HtmlPreviewScreen(
              htmlCode: tab.controller.text,
              projectUri: projectUri,
              htmlFileUri: tab.fileUri!,
            ),
          ),
        );
        return;

      case LanguageEngine.webCode:
        final mode =
            LanguageEngineManager.webModeForFile(tab.fileName);

        if (mode == null) {
          showMessage('نوع ملف الويب غير مدعوم');
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: mode,
            ),
          ),
        );
        return;

      case LanguageEngine.jsonViewer:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: 'json',
            ),
          ),
        );
        return;

      case LanguageEngine.unsupported:
        final extension = tab.fileName.contains('.')
            ? tab.fileName.split('.').last.toLowerCase()
            : '';

        if (extension == 'ts' || extension == 'tsx') {
          showMessage(
            'TypeScript يحتاج إلى إضافة مترجم محلي قبل التشغيل. '
            'سنضيفه في المرحلة التالية.',
          );
        } else {
          showMessage(
            'لا يوجد محرك تشغيل محلي لهذا النوع حتى الآن. '
            'الملف يبقى قابلًا للتحرير والحفظ.',
          );
        }
        return;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildExplorerNode(String directoryUri, int depth) {
    return FutureBuilder<List<SafDocumentFile>>(
      key: ValueKey('$_explorerRevision-$directoryUri'),
      future: safFiles.listDirectory(directoryUri),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const ListTile(
            dense: true,
            title: Text('تعذر قراءة المجلد'),
          );
        }

        final items =
            List<SafDocumentFile>.from(snapshot.data ?? []);

        items.sort((a, b) {
          if (a.isDir && !b.isDir) return -1;
          if (!a.isDir && b.isDir) return 1;

          return a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
        });

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'المجلد فارغ',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((entity) {
            if (entity.isDir) {
              final isSelectedDirectory =
                  selectedDirectoryUri == entity.uri;

              return Padding(
                padding: EdgeInsets.only(right: depth * 5.0),
                child: ExpansionTile(
                  key: PageStorageKey<String>(entity.uri),
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: Icon(
                    isSelectedDirectory
                        ? Icons.folder_special
                        : Icons.folder,
                    color: isSelectedDirectory
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFFBBF24),
                    size: 20,
                  ),
                  title: Text(
                    entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelectedDirectory
                          ? const Color(0xFF38BDF8)
                          : null,
                      fontWeight: isSelectedDirectory
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'select') {
                        selectCreationDirectory(
                          entity.uri,
                          entity.name,
                        );
                      }

                      if (value == 'rename') {
                        renameEntity(entity);
                      }

                      if (value == 'delete') {
                        deleteEntity(entity);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(
                              Icons.drive_file_move,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('تعيين كمجلد عمل'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('إعادة تسمية'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                  children: [
                    buildExplorerNode(entity.uri, depth + 1),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(right: depth * 5.0),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Color(0xFF38BDF8),
                  size: 19,
                ),
                title: Text(
                  entity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => openProjectFile(entity, directoryUri),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'rename') {
                      renameEntity(entity);
                    }

                    if (value == 'delete') {
                      deleteEntity(entity);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('إعادة تسمية'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildExplorer() {
    return Container(
      width: 115,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المستكشف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: createProjectFile,
                  icon: const Icon(Icons.note_add, size: 19),
                  tooltip: 'ملف جديد',
                ),
                IconButton(
                  onPressed: createProjectFolder,
                  icon: const Icon(Icons.create_new_folder, size: 19),
                  tooltip: 'مجلد جديد',
                ),
                IconButton(
                  onPressed: refreshExplorer,
                  icon: const Icon(Icons.refresh, size: 19),
                  tooltip: 'تحديث المستكشف',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (projectUri == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 38,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لم يتم فتح مشروع',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: openProjectFolder,
                        child: const Text('فتح مجلد'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.folder,
                      color: Color(0xFFFBBF24),
                    ),
                    title: Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: openProjectFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selectedDirectoryUri != null
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedDirectoryUri != null
                              ? Icons.folder_special
                              : Icons.home_work,
                          size: 15,
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'العمل: $creationDirectoryName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        if (selectedDirectoryUri != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'العودة إلى جذر المشروع',
                            onPressed: resetCreationDirectory,
                            icon: const Icon(
                              Icons.home,
                              size: 17,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildExplorerNode(projectUri!, 0),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      height: 46,
      color: const Color(0xFF111827),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = index == activeIndex;

                return InkWell(
                  onTap: () => selectTab(index),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 100,
                      maxWidth: 180,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0B1020)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          size: 15,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tab.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (!tab.isSaved)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.amber,
                            ),
                          ),
                        GestureDetector(
                          onTap: () => closeTab(index),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: createNewTab,
            icon: const Icon(
              Icons.add,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final tab in tabs) {
      tab.controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tab = activeTab;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF151C30),
          title: const Row(
            children: [
              Icon(
                Icons.code,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Text(
                'Bisho IDE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: openFlutterPreview,
              icon: const Icon(
                Icons.phone_android,
                color: Color(0xFF38BDF8),
              ),
              tooltip: 'معاينة Flutter',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  explorerVisible = !explorerVisible;
                });
              },
              icon: const Icon(Icons.folder_open),
              tooltip: 'المستكشف',
            ),
            IconButton(
              onPressed: saveCurrentToDisk,
              icon: const Icon(Icons.save),
              tooltip: 'حفظ الملف',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'new') createNewTab();
                if (value == 'new_project') createNewProject();
                if (value == 'open') openFile();
                if (value == 'folder') openProjectFolder();
                if (value == 'export') exportFile();
                if (value == 'search') searchCode();
                if (value == 'copy') copyCode();
                if (value == 'saveall') saveAllTabs();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'new',
                  child: Text('ملف جديد'),
                ),
                PopupMenuItem(
                  value: 'new_project',
                  child: Row(
                    children: [
                      Icon(
                        Icons.create_new_folder,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 8),
                      Text('إنشاء مشروع جديد'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open',
                  child: Text('فتح ملف'),
                ),
                PopupMenuItem(
                  value: 'folder',
                  child: Text('فتح مجلد مشروع'),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text('تصدير الملف'),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: Text('بحث'),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Text('نسخ الكود'),
                ),
                PopupMenuItem(
                  value: 'saveall',
                  child: Text('حفظ جميع الملفات'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            buildTabBar(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              color: const Color(0xFF111827),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DropdownButton<String>(
                    value: tab.language,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    items: languages.keys.map((language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: changeLanguage,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  toolButton(Icons.add, 'جديد', createNewTab),
                  toolButton(Icons.folder_open, 'فتح', openFile),
                  toolButton(Icons.folder, 'مشروع', openProjectFolder),
                  toolButton(
                    Icons.create_new_folder,
                    'مشروع جديد',
                    createNewProject,
                  ),
                  toolButton(Icons.save, 'حفظ', saveCurrentToDisk),
                  toolButton(Icons.download, 'تصدير', exportFile),
                  toolButton(Icons.search, 'بحث', searchCode),
                  toolButton(Icons.copy, 'نسخ', copyCode),
                  toolButton(
                    Icons.phone_android,
                    'معاينة Flutter',
                    openFlutterPreview,
                  ),
                  toolButton(
                    Icons.language,
                    'تشغيل / معاينة',
                    openLanguagePreview,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (explorerVisible) buildExplorer(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080D19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF26334D),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CodeTheme(
                        data: CodeThemeData(
                          styles: monokaiSublimeTheme,
                        ),
                        child: CodeField(
                          key: ValueKey(tab.id),
                          controller: tab.controller,
                          expands: true,
                          wrap: false,
                          padding: const EdgeInsets.all(12),
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                          gutterStyle: const GutterStyle(
                            showLineNumbers: true,
                            showErrors: true,
                            showFoldingHandles: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFF151C30),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    color: Colors.green,
                    size: 9,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Text(
                    tab.language,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.isSaved ? 'محفوظ' : 'غير محفوظ',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget toolButton(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}