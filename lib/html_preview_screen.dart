
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'core/services/saf_file_service.dart';

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlCode;
  final String? projectUri;
  final String htmlFileUri;

  const HtmlPreviewScreen({
    super.key,
    required this.htmlCode,
    required this.htmlFileUri,
    this.projectUri,
  });

  @override
  State<HtmlPreviewScreen> createState() =>
      _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController _controller;

  final SafFileService _safFiles = SafFileService();

  bool _isLoading = true;
  String? _error;

  Directory? _previewDirectory;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        const Color(0xFF101318),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _error = null;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            // تجاهل أخطاء الموارد الفرعية هنا.
            // قد تكون بعض الموارد اختيارية في المشروع.
            if (error.isForMainFrame == false) return;

            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
        ),
      );

    _loadPage();
  }

  // إنشاء مسار محلي آمن داخل مجلد المعاينة.
  String _joinPath(
    String parent,
    String child,
  ) {
    final safeName = child.replaceAll(
      '\\',
      '/',
    );

    if (safeName.isEmpty ||
        safeName == '.' ||
        safeName == '..' ||
        safeName.startsWith('/') ||
        safeName.contains('/')) {
      throw Exception(
        'اسم ملف أو مجلد غير صالح: $child',
      );
    }

    return '$parent${Platform.pathSeparator}$safeName';
  }

  // التحقق من اسم ملف HTML.
  bool _isHtmlFile(String name) {
    final lower = name.toLowerCase();

    return lower.endsWith('.html') ||
        lower.endsWith('.htm');
  }

  // نسخ ملفات المشروع من SAF إلى المجلد المؤقت.
  //
  // يتم الاحتفاظ بالهيكل الأصلي للمجلدات.
  // وتتم إعادة المسار النسبي لملف HTML المطلوب.
  Future<String?> _copyProjectDirectory({
    required String sourceUri,
    required String destinationPath,
    required String htmlFileUri,
    String relativePath = '',
  }) async {
    final items = await _safFiles.listDirectory(
      sourceUri,
    );

    String? htmlRelativePath;

    for (final item in items) {
      final name = item.name;

      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains('/') ||
          name.contains('\\')) {
        continue;
      }

      final currentRelativePath = relativePath.isEmpty
          ? name
          : '$relativePath/$name';

      final destinationItemPath = _joinPath(
        destinationPath,
        name,
      );

      if (item.isDir) {
        final directory = Directory(
          destinationItemPath,
        );

        await directory.create(
          recursive: true,
        );

        final nestedHtmlPath =
            await _copyProjectDirectory(
          sourceUri: item.uri,
          destinationPath: destinationItemPath,
          htmlFileUri: htmlFileUri,
          relativePath: currentRelativePath,
        );

        if (nestedHtmlPath != null) {
          htmlRelativePath = nestedHtmlPath;
        }
      } else {
        try {
          final bytes = await _safFiles.readFile(
            item.uri,
          );

          final outputFile = File(
            destinationItemPath,
          );

          await outputFile.parent.create(
            recursive: true,
          );

          await outputFile.writeAsBytes(
            bytes,
            flush: true,
          );

          if (item.uri == htmlFileUri) {
            htmlRelativePath = currentRelativePath;
          }
        } catch (e) {
          debugPrint(
            'تعذرت قراءة الملف $name: $e',
          );
        }
      }
    }

    return htmlRelativePath;
  }

  // إنشاء مجلد مؤقت مستقل لكل عملية معاينة.
  Future<Directory> _createPreviewDirectory() async {
    final temporaryDirectory =
        await getTemporaryDirectory();

    final previewPath =
        '${temporaryDirectory.path}'
        '${Platform.pathSeparator}'
        'bisho_preview_${DateTime.now().microsecondsSinceEpoch}';

    final directory = Directory(
      previewPath,
    );

    await directory.create(
      recursive: true,
    );

    return directory;
  }

  // حذف مجلد المعاينة السابق.
  Future<void> _deletePreviousPreview() async {
    final oldDirectory = _previewDirectory;

    _previewDirectory = null;

    if (oldDirectory == null) return;

    try {
      if (await oldDirectory.exists()) {
        await oldDirectory.delete(
          recursive: true,
        );
      }
    } catch (e) {
      debugPrint(
        'تعذر حذف ملفات المعاينة السابقة: $e',
      );
    }
  }

  // تجهيز المشروع وفتح ملف HTML.
  Future<void> _loadPage() async {
    try {
      if (widget.projectUri == null ||
          widget.projectUri!.isEmpty) {
        throw Exception(
          'لم يتم تحديد مجلد المشروع.',
        );
      }

      if (widget.htmlFileUri.isEmpty) {
        throw Exception(
          'تعذر تحديد ملف HTML.',
        );
      }

      await _deletePreviousPreview();

      if (!mounted) return;

      final previewDirectory =
          await _createPreviewDirectory();

      _previewDirectory = previewDirectory;

      final htmlRelativePath =
          await _copyProjectDirectory(
        sourceUri: widget.projectUri!,
        destinationPath: previewDirectory.path,
        htmlFileUri: widget.htmlFileUri,
      );

      if (htmlRelativePath == null) {
        throw Exception(
          'لم يتم العثور على ملف HTML داخل مجلد المشروع. '
          'تأكد من أن الملف موجود وأن صلاحية الوصول إلى المجلد محفوظة.',
        );
      }

      // استبدال النسخة المؤقتة بمحتوى المحرر الحالي.
      // هذا يسمح بمعاينة التعديلات غير المحفوظة.
      final normalizedRelativePath =
          htmlRelativePath.replaceAll(
        '/',
        Platform.pathSeparator,
      );

      final htmlFile = File(
        '${previewDirectory.path}'
        '${Platform.pathSeparator}'
        '$normalizedRelativePath',
      );

      await htmlFile.writeAsString(
        widget.htmlCode,
        flush: true,
      );

      if (!mounted) return;

      if (!await htmlFile.exists()) {
        throw Exception(
          'تعذر إنشاء ملف HTML المؤقت.',
        );
      }

      // فتح ملف HTML المحلي مباشرة.
      await _controller.loadFile(
        htmlFile.path,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // إعادة تجهيز المشروع بالكامل.
  Future<void> _reloadPage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadPage();
  }

  @override
  void dispose() {
    final directory = _previewDirectory;

    if (directory != null) {
      unawaited(
        directory.delete(
          recursive: true,
        ).catchError((Object error) {
          debugPrint(
            'تعذر حذف مجلد المعاينة: $error',
          );
          return directory;
        }),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191E26),
        foregroundColor: Colors.white,
        title: const Text(
          'معاينة مشروع الويب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading
                ? null
                : _reloadPage,
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'إعادة تحميل المشروع',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),

          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33101318),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          if (_error != null)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF101318),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252B35),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white12,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 44,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'تعذر عرض المشروع',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _reloadPage,
                          icon: const Icon(
                            Icons.refresh,
                          ),
                          label: const Text(
                            'إعادة المحاولة',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}