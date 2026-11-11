
import 'package:flutter/material.dart';

class FlutterPreviewScreen extends StatefulWidget {
  final String projectName;

  const FlutterPreviewScreen({
    super.key,
    this.projectName = 'مشروع Flutter',
  });

  @override
  State<FlutterPreviewScreen> createState() =>
      _FlutterPreviewScreenState();
}

class _FlutterPreviewScreenState
    extends State<FlutterPreviewScreen> {
  String status = 'لم يبدأ التشغيل بعد';
  String buildLog =
      'مرحباً بك في معاينة Flutter.\n'
      'اختر تشغيل المشروع لبدء عملية البناء.\n';

  bool isBuilding = false;
  bool isRunning = false;

  void startBuild() {
    setState(() {
      isBuilding = true;
      isRunning = false;
      status = 'بانتظار بيئة البناء';
      buildLog =
          'تم طلب بناء المشروع.\n'
          'يجب ربط هذه الشاشة بخادم Flutter Build '
          'لتنفيذ البناء الفعلي.\n';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'واجهة المعاينة جاهزة، يلزم ربط خدمة البناء لتشغيل المشروع.',
        ),
      ),
    );
  }

  void stopBuild() {
    setState(() {
      isBuilding = false;
      isRunning = false;
      status = 'تم إيقاف جلسة المعاينة';
      buildLog += '\nتم إيقاف جلسة المعاينة.\n';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1020),
        appBar: AppBar(
          backgroundColor: const Color(0xFF151C30),
          title: const Text(
            'معاينة Flutter',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  buildLog = 'تم تحديث سجل المعاينة.\n';
                });
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث السجل',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF111827),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.projectName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        isRunning
                            ? Icons.check_circle
                            : Icons.circle,
                        color: isRunning
                            ? Colors.green
                            : Colors.orange,
                        size: 11,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF080D19),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF26334D),
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.phone_android,
                          size: 76,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'مساحة معاينة التطبيق',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'ستظهر هنا واجهة تطبيق Flutter '
                          'بعد نجاح البناء وتشغيله.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Chip(
                          label: Text(
                            'بيئة التشغيل غير متصلة بعد',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF111827),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سجل البناء',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 105,
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080D19),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        buildLog,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              isBuilding ? null : startBuild,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('تشغيل'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              isBuilding || isRunning
                                  ? stopBuild
                                  : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('إيقاف'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}