import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebCodeRunnerScreen extends StatefulWidget {
  final String code;
  final String fileName;
  final String mode;

  const WebCodeRunnerScreen({
    super.key,
    required this.code,
    required this.fileName,
    required this.mode,
  });

  @override
  State<WebCodeRunnerScreen> createState() =>
      _WebCodeRunnerScreenState();
}

class _WebCodeRunnerScreenState extends State<WebCodeRunnerScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF101318))
      ..addJavaScriptChannel(
        'BishoConsole',
        onMessageReceived: (message) {
          if (!mounted) return;
          setState(() {
            _logs.add(message.message);
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
        ),
      );

    _loadCode();
  }

  String _document() {
    final encoded = base64Encode(utf8.encode(widget.code));

    if (widget.mode == 'javascript') {
      return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{margin:0;padding:16px;background:#101318;color:#e5e7eb;font:14px monospace}
h3{font:600 16px Arial;color:#38bdf8}
#status{color:#86efac;margin-bottom:12px}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#080d19;padding:12px;border-radius:8px;min-height:120px}
</style>
</head>
<body>
<h3>Bisho IDE · JavaScript Runner</h3>
<div id="status">جارٍ تنفيذ JavaScript...</div>
<pre id="output"></pre>
<script>
(function(){
  const output=document.getElementById('output');
  const status=document.getElementById('status');
  function stringify(v){
    if(typeof v==='string') return v;
    try{return JSON.stringify(v, null, 2)}catch(_){return String(v)}
  }
  function send(level,args){
    const line='['+level+'] '+Array.from(args).map(stringify).join(' ');
    output.textContent += line+'\\n';
    if(window.BishoConsole) BishoConsole.postMessage(line);
  }
  ['log','info','warn','error','debug'].forEach(function(level){
    const original=console[level].bind(console);
    console[level]=function(){
      send(level,arguments);
      original.apply(console,arguments);
    };
  });
  window.onerror=function(message,source,line,column,error){
    send('error',[message+' ('+line+':'+column+')']);
    status.textContent='اكتمل التنفيذ مع وجود خطأ';
    return true;
  };
  try{
    const bytes=Uint8Array.from(atob('$encoded'),c=>c.charCodeAt(0));
    const code=new TextDecoder().decode(bytes);
    (new Function(code))();
    status.textContent='اكتمل تنفيذ JavaScript';
  }catch(error){
    send('error',[error && error.stack ? error.stack : String(error)]);
    status.textContent='فشل تنفيذ JavaScript';
  }
})();
</script>
</body>
</html>
''';
    }

    if (widget.mode == 'css') {
      return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{margin:0;padding:24px;background:#101318;color:#e5e7eb;font-family:Arial,sans-serif}
.demo{max-width:520px;margin:30px auto;padding:24px;border-radius:16px;background:#1e293b}
h1{color:#38bdf8}button{padding:10px 18px;border:0;border-radius:8px;background:#0ea5e9;color:white}
${
        widget.code
      }
</style></head>
<body>
<div class="demo">
<h1>معاينة CSS</h1>
<p>هذه مساحة تجريبية لمعاينة تنسيقات CSS.</p>
<button>زر تجريبي</button>
</div>
</body></html>
''';
    }

    if (widget.mode == 'svg') {
      return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{margin:0;background:#101318;color:white;display:grid;place-items:center;min-height:100vh}</style>
</head><body>${widget.code}</body></html>
''';
    }

    final safeJson = const HtmlEscape().convert(widget.code);
    return '''
<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{margin:0;padding:16px;background:#101318;color:#e5e7eb;font:14px monospace}
pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#080d19;padding:14px;border-radius:8px}</style>
</head><body><pre>$safeJson</pre></body></html>
''';
  }

  Future<void> _loadCode() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _logs.clear();
    });

    try {
      await _controller.loadHtmlString(_document());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191E26),
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _loadCode,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة التشغيل',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.mode == 'javascript')
            Container(
              height: 150,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF080D19),
                border: Border(
                  top: BorderSide(color: Colors.white12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        size: 17,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'مخرجات JavaScript',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(_logs.clear);
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 19,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
