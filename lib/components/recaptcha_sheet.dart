import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/recaptcha_service.dart';

/// หน้าจอให้ผู้ใช้ยืนยัน reCAPTCHA จริงกับ Google (คีย์เดียวกับเว็บ)
/// คืนค่าเป็น token ของ reCAPTCHA (หรือ null เมื่อผู้ใช้ปิด/ยืนยันไม่สำเร็จ)
///
/// ตัววิดเจ็ตถูกโหลดจาก HTML ในแอป โดยตั้ง baseUrl เป็นโดเมนที่ลงทะเบียนไว้กับ
/// site key แล้ว เพื่อให้ Google ออก token ให้แอปได้โดยไม่ต้องมีหน้าเว็บโฮสต์จริง
/// (baseUrl เป็นเพียงที่มาของเอกสาร ไม่ได้ถูกเรียกผ่านเครือข่าย จึงใช้ได้แม้ tunnel ปิด)
///
/// ⚠️ ต้องเป็นโดเมนที่อยู่ในรายการ Domains ของคีย์ reCAPTCHA เท่านั้น — ห้ามผูกกับ
/// `Config.url_server` เพราะตอนทดสอบกับ server ในเครื่องค่านั้นเป็น IP
/// (เช่น 10.0.2.2) ซึ่ง Google ไม่รับ และจะขึ้น "ERROR for site owner" แทนวิดเจ็ต
class RecaptchaSheet extends StatefulWidget {
  const RecaptchaSheet({Key? key}) : super(key: key);

  /// โดเมนที่ลงทะเบียนกับคีย์ reCAPTCHA (ดูรายการได้ที่ Google reCAPTCHA console)
  static const String _baseUrl =
      'https://taneka-rarefied-regrettably.ngrok-free.dev/';

  static const String _html = '''
<!doctype html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin:0; padding:0; background:#0B1220; color:#E5EDF7;
    font-family:-apple-system,"Segoe UI",Roboto,"Noto Sans Thai",sans-serif;
    display:flex; flex-direction:column; align-items:center; justify-content:center; min-height:100vh; }
  #status { font-size:14px; opacity:.8; margin-bottom:12px; }
</style>
<script>
  function onRecaptchaSuccess(token) {
    document.getElementById('status').textContent = 'ยืนยันสำเร็จ';
    try { RecaptchaToken.postMessage(token); } catch (e) {}
  }
  function onRecaptchaExpired() {
    document.getElementById('status').textContent = 'หมดอายุ กรุณายืนยันใหม่';
    try { RecaptchaToken.postMessage(''); } catch (e) {}
  }
  function onRecaptchaError() {
    document.getElementById('status').textContent = 'โหลด reCAPTCHA ไม่สำเร็จ';
    try { RecaptchaToken.postMessage(''); } catch (e) {}
  }
</script>
<script src="https://www.google.com/recaptcha/api.js" async defer></script>
</head>
<body>
  <div id="status">กรุณายืนยันว่าคุณไม่ใช่บอท</div>
  <div class="g-recaptcha"
       data-sitekey="${RecaptchaVerifyService.siteKey}"
       data-callback="onRecaptchaSuccess"
       data-expired-callback="onRecaptchaExpired"
       data-error-callback="onRecaptchaError"
       data-theme="dark"></div>
</body>
</html>
''';

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecaptchaSheet(),
    );
  }

  @override
  State<RecaptchaSheet> createState() => _RecaptchaSheetState();
}

class _RecaptchaSheetState extends State<RecaptchaSheet> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B1220))
      ..addJavaScriptChannel(
        'RecaptchaToken',
        onMessageReceived: (JavaScriptMessage message) {
          final token = message.message.trim();
          if (!mounted || _done) return;
          if (token.isEmpty) {
            setState(() => _failed = true);
            return;
          }
          _done = true;
          Navigator.of(context).pop(token);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // ปล่อยผ่าน error ของ subresource; ถือว่าโหลดพังเมื่อหน้าโหลดไม่ขึ้น
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadHtmlString(RecaptchaSheet._html, baseUrl: RecaptchaSheet._baseUrl);
  }

  void _reload() {
    setState(() {
      _failed = false;
      _loading = true;
      _done = false;
    });
    _controller.loadHtmlString(RecaptchaSheet._html,
        baseUrl: RecaptchaSheet._baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.72;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFF0B1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.security, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ยืนยันว่าไม่ใช่บอท',
                    style: TextStyle(
                      fontFamily: 'Kanit',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  tooltip: 'ปิด',
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_failed)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'โหลด reCAPTCHA ไม่สำเร็จ กรุณาลองใหม่',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Kanit',
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _reload,
                            child: const Text('ลองใหม่'),
                          ),
                        ],
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
