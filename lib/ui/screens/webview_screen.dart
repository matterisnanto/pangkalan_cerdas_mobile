import 'dart:collection';
import 'dart:convert';

import '../../services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/firebase_service.dart';

class WebViewScreen extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  const WebViewScreen({super.key, this.onBackToDashboard});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen>
    with AutomaticKeepAliveClientMixin {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  double _loadProgress = 0;
  bool _tokenCaptured = false;
  bool _isMerchantLogin = false;
  List<Map<String, String>> _accounts = [];
  final _storage = SecureStorageService();
  String _tempUsername = '';
  String _tempPassword = '';
  String? _lastProcessedDashboardUrl;
  bool _isShowingAccountSuggestions = false;
  bool _silentLoginInProgress = false;

  Future<void> _attemptSilentLogin(Uri? url) async {
    final currentUrl = url?.toString().toLowerCase() ?? '';
    final isLoginPage =
        currentUrl.contains('/login') || currentUrl.contains('/merchant-login');
    if (!isLoginPage || _silentLoginInProgress) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isTokenAvailable || !auth.isTokenValid) return;
    await _loadAccounts();
    if (!mounted || _accounts.isEmpty) return;
    final account = _accounts.firstWhere(
      (item) =>
          (item['username'] ?? '').trim().isNotEmpty &&
          (item['password'] ?? '').trim().isNotEmpty,
      orElse: () => <String, String>{},
    );
    if (account.isEmpty) return;

    _silentLoginInProgress = true;
    try {
      await _fillAccount(account);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _controller?.evaluateJavascript(
        source: '''
          (function() {
            const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]'));
            const button = buttons.find((item) =>
              /masuk|login|sign in/i.test((item.innerText || item.value || '').trim()));
            if (button) button.click();
          })();
        ''',
      );
    } finally {
      _silentLoginInProgress = false;
    }
  }

  Future<void> _loadAccounts() async {
    final raw = await _storage.readPangkalanAccounts();
    if (raw == null || raw.isEmpty) {
      _accounts = [];
      return;
    }
    try {
      _accounts = (jsonDecode(raw) as List)
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fillAccount(Map<String, String> account) async {
    final controller = _controller;
    if (controller == null) return;
    final username = jsonEncode(account['username'] ?? '');
    final password = jsonEncode(account['password'] ?? '');
    await controller.evaluateJavascript(
      source:
          '''
      (function() {
        function setNativeInputValue(element, value) {
          if (!element) return;
          const valueSetter = Object.getOwnPropertyDescriptor(element, 'value')?.set;
          const prototype = Object.getPrototypeOf(element);
          const prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value')?.set;
          if (prototypeValueSetter && valueSetter !== prototypeValueSetter) {
            prototypeValueSetter.call(element, value);
          } else if (valueSetter) {
            valueSetter.call(element, value);
          } else {
            element.value = value;
          }
          element.dispatchEvent(new Event('input', { bubbles: true }));
          element.dispatchEvent(new Event('change', { bubbles: true }));
          element.dispatchEvent(new Event('blur', { bubbles: true }));
        }
        const inputs = document.querySelectorAll('input');
        inputs.forEach(input => {
          if (input.type === 'text' || input.name === 'username' || input.id === 'username') {
            setNativeInputValue(input, $username);
          }
          if (input.type === 'password' || input.name === 'password' || input.id === 'password') {
            setNativeInputValue(input, $password);
          }
        });
      })();
    ''',
    );
  }

  Future<void> _showAccountSuggestions() async {
    if (_isShowingAccountSuggestions) return;
    debugPrint('🔑 [AUTOFILL TRIGGERED] Kolom input login diklik di WebView');
    await _loadAccounts();
    if (!mounted) return;
    if (_accounts.isEmpty) {
      return;
    }
    if (_isShowingAccountSuggestions) return;
    _isShowingAccountSuggestions = true;
    try {
      final account = await showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: Color(0xFF00AA5B)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pilih Akun Pangkalan untuk Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const Divider(),
                ..._accounts.map(
                  (account) => Card(
                    elevation: 0,
                    color: const Color(0xFFF4F8F6),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDDF5E8),
                        child: Icon(Icons.key, color: Color(0xFF00AA5B)),
                      ),
                      title: Text(
                        account['name'] ?? 'Pangkalan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(account['username'] ?? ''),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF5E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Tersimpan',
                          style: TextStyle(
                            color: Color(0xFF087F45),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pop(sheetContext, account),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (account != null) await _fillAccount(account);
    } finally {
      _isShowingAccountSuggestions = false;
    }
  }

  Future<void> _captureManualLogin(List<dynamic> args) async {
    if (args.length < 2) return;
    final username = args[0]?.toString().trim() ?? '';
    final password = args[1]?.toString() ?? '';
    if (username.isEmpty || password.isEmpty) return;
    _tempUsername = username;
    _tempPassword = password;
  }

  Future<void> _handleUrl(Uri? url, InAppWebViewController controller) async {
    final value = url?.toString() ?? '';
    final isLogin =
        value.contains('/merchant-login') || value.contains('/login');
    if (isLogin != _isMerchantLogin && mounted) {
      setState(() => _isMerchantLogin = isLogin);
    }
    if (isLogin) {
      await controller.evaluateJavascript(source: _autofillFocusListenerScript);
      await controller.evaluateJavascript(source: _manualLoginListenerScript);
      return;
    }
    final isDashboard =
        value.contains('/dashboard') || value.contains('/merchant/home');
    if (!isDashboard ||
        _tempUsername.isEmpty ||
        _tempPassword.isEmpty ||
        _lastProcessedDashboardUrl == value) {
      return;
    }
    _lastProcessedDashboardUrl = value;
    final result = await controller.evaluateJavascript(
      source: _profileNameScript,
    );
    final name = (result?.toString().trim() ?? '').isEmpty
        ? 'Pangkalan MyPertamina'
        : result.toString().trim();
    final updated = <Map<String, String>>[
      ..._accounts.where((account) => account['username'] != _tempUsername),
      {'name': name, 'username': _tempUsername, 'password': _tempPassword},
    ];
    await _storage.savePangkalanAccounts(jsonEncode(updated));
    _accounts = updated;
    _tempUsername = '';
    _tempPassword = '';
    if (mounted) {
      setState(() {});
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: true,
              bottom: false,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri('https://subsiditepatlpg.mypertamina.id/'),
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source:
                        _firebaseMessagingSuppressorScript +
                        _tokenInterceptorScript +
                        _safeCustomerCaptureScript +
                        _diagnosticCustomerCaptureScript +
                        _dataCaptureScript +
                        _transactionBridgeScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: false,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  hardwareAcceleration: true,
                  useHybridComposition: true,
                  thirdPartyCookiesEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  clearCache: false,
                  clearSessionCache: false,
                  cacheEnabled: true,
                  sharedCookiesEnabled: true,
                  useShouldInterceptRequest: true,
                  useOnLoadResource: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                ),
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('🌐 [WEBVIEW JS] ${consoleMessage.message}');
                },
                onWebViewCreated: (controller) {
                  _controller = controller;
                  debugPrint(
                    '🌐 [WEBVIEW JS] Interceptor aktif & mendengarkan Fetch/XHR request...',
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onTokenCaptured',
                    callback: (args) async {
                      if (args.isEmpty || args.first is! String) return;
                      final token = (args.first as String).trim();
                      if (token.isEmpty) return;
                      await _handleTokenCaptured(token);
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onRequestAccountSuggestions',
                    callback: (args) async {
                      await _showAccountSuggestions();
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onManualLoginAttempt',
                    callback: (args) async {
                      await _captureManualLogin(args);
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onMyPertaminaDataCaptured',
                    callback: (args) async {
                      if (args.isEmpty || args.first is! Map) return;
                      final data = Map<String, dynamic>.from(args.first as Map);
                      final auth = context.read<AuthProvider>();
                      await context
                          .read<CustomerProvider>()
                          .autoSaveCustomerFromPortal(data);
                      final customers = await FirebaseService().getAllPelanggan(
                        auth.registrationId,
                      );
                      await context
                          .read<TransactionProvider>()
                          .syncAndSaveMyPertaminaTransactionsThisYear(
                            customers,
                          );
                      debugPrint(
                        '✅ [AUTO-CAPTURE] Berhasil menyimpan pelanggan & transaksi dari portal!',
                      );
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onMyPertaminaCustomerCaptured',
                    callback: (args) async {
                      debugPrint('📥 [FLUTTER STEP 5 RECEIVED] Raw args: $args');
                      if (args.isEmpty || args.first == null) {
                        debugPrint('⚠️ [FLUTTER WARNING] Payload kosong!');
                        return;
                      }
                      try {
                        final data = Map<String, dynamic>.from(args.first as Map);
                        final nik = data['nik']?.toString().trim() ?? '';
                        debugPrint('🔍 [FLUTTER PARSED DATA] NIK: $nik | Nama: ${data['nama'] ?? data['name']} | Kuota: ${data['remainingQuota']}');
                        if (nik.length == 16) {
                          debugPrint('💾 [SQLITE DIRECT SAVE] Menyimpan NIK $nik ke database SQLite...');
                          await context.read<CustomerProvider>().autoSaveCustomerFromPortalQuota(data);
                          debugPrint('✅ [SQLITE AUTO-SAVE SUCCESS] NIK $nik BERHASIL tersimpan & UI diperbarui!');
                        } else {
                          debugPrint('⚠️ [FLUTTER CANCELLED] NIK tidak 16 digit: "$nik"');
                        }
                      } catch (e, stack) {
                        debugPrint('❌ [FLUTTER HANDLER EXCEPTION]: $e\n$stack');
                      }
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'onMyPertaminaTransactionCaptured',
                    callback: (args) async {
                      if (args.isEmpty) return;
                      debugPrint(
                        '📩 [FLUTTER JS HANDLER] Event transaksi manual diterima dari WebView!',
                      );
                      debugPrint('📦 [WEBVIEW CAPTURED PAYLOAD]: ${args.first}');
                      try {
                        final decoded = args.first is String
                            ? jsonDecode(args.first as String)
                            : args.first;
                        if (decoded is! Map) return;
                        final txData = Map<String, dynamic>.from(decoded);
                        final auth = context.read<AuthProvider>();
                        final registrationId = auth.registrationId ?? 'PANGKALAN_DEFAULT';
                        await context.read<TransactionProvider>()
                            .saveCapturedTransactionToLocal(registrationId, txData);
                        await context.read<CustomerProvider>()
                            .autoSaveCustomerFromTransactionPayload(txData);
                        debugPrint('✅ [SQLITE SUCCESS] Transaksi & pelanggan tersimpan lokal.');
                      } catch (e, stackTrace) {
                        debugPrint('❌ [AUTO-CAPTURE] $e\n$stackTrace');
                      }
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'myPertaminaTransaction',
                    callback: (args) async {
                      if (args.isEmpty || args.first is! Map) return;
                      final auth = context.read<AuthProvider>();
                      await FirebaseService().saveInterceptedTransaction(
                        registrationId: auth.registrationId,
                        payload: Map<String, dynamic>.from(args.first as Map),
                      );
                    },
                  );
                },
                onLoadStop: (controller, url) async {
                  await controller.evaluateJavascript(
                    source: _retryBridgeOnLoadStopScript,
                  );
                  await controller.evaluateJavascript(
                    source: _transactionBridgeScript,
                  );
                  await controller.evaluateJavascript(
                    source:
                        "document.documentElement.style.paddingBottom = '120px';",
                  );
                  await _handleUrl(url, controller);
                  await _attemptSilentLogin(url);
                  if (url.toString() ==
                          'https://subsiditepatlpg.mypertamina.id/' ||
                      url.toString() ==
                          'https://subsiditepatlpg.mypertamina.id') {
                    await controller.evaluateJavascript(
                      source:
                          "if(window.location.pathname !== '/merchant-login') { window.location.href = '/merchant-login'; }",
                    );
                  }
                },
                onUpdateVisitedHistory:
                    (controller, url, androidIsReload) async {
                      await _handleUrl(url, controller);
                      await _attemptSilentLogin(url);
                    },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _loadProgress = progress.toDouble();
                    _isLoading = progress < 100;
                  });
                },
                shouldInterceptRequest: (controller, request) async {
                  _extractToken(request.headers);
                  return null;
                },
                onLoadResource: (controller, resource) async {
                  final resourceUrl = resource.url?.toString() ?? '';
                  if (resourceUrl.contains('/customers/') ||
                      resourceUrl.contains('/verify-nik') ||
                      resourceUrl.contains('/quota')) {
                    final match = RegExp(r'\b\d{16}\b').firstMatch(resourceUrl);
                    if (match != null) {
                      final nik = match.group(0)!;
                      debugPrint('📡 [NATIVE CAPTURE] Fallback NIK $nik terdeteksi via onLoadResource');
                      await context.read<CustomerProvider>().autoSaveCustomerFromPortalQuota({
                        'nik': nik,
                        'category': 'Rumah Tangga',
                        'isEnriched': 1,
                      });
                    }
                  }
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: Colors.black.withValues(alpha: .58),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _controller?.reload(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tokenCaptured
                                ? Icons.verified
                                : Icons.vpn_key_outlined,
                            color: _tokenCaptured
                                ? Colors.greenAccent
                                : Colors.white70,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _tokenCaptured
                                ? 'Token aktif'
                                : (_isLoading
                                      ? 'Memuat portal'
                                      : 'Login portal'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                value: _loadProgress / 100,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const String _firebaseMessagingSuppressorScript = r'''
(function() {
  if (window.__pcFirebaseMessagingSuppressor) return;
  window.__pcFirebaseMessagingSuppressor = true;
  window.addEventListener('unhandledrejection', function(event) {
    var reason = event.reason;
    var message = reason && reason.message ? String(reason.message) : '';
    var code = reason && reason.code ? String(reason.code) : '';
    if (message.indexOf('messaging/unsupported-browser') >= 0 ||
        code.indexOf('messaging/unsupported-browser') >= 0) {
      event.preventDefault();
      console.log('🛡️ [WEBVIEW] Firebase messaging unsupported-browser suppressed');
    }
  });
  if (!('Notification' in window)) {
    window.Notification = {
      permission: 'denied',
      requestPermission: function() { return Promise.resolve('denied'); }
    };
  }
})();
''';

  static const String _tokenInterceptorScript = r'''
(function() {
  if (window.__pcTokenInterceptor) return;
  window.__pcTokenInterceptor = true;
  function capture(value) {
    if (typeof value !== 'string' || value.indexOf('Bearer ') !== 0) return;
    var token = value.substring(7).trim();
    if (token && window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('onTokenCaptured', token);
    }
  }
  var originalFetch = window.fetch;
  window.fetch = function(input, init) {
    if (init && init.headers) {
      var headers = init.headers;
      if (typeof headers.get === 'function') capture(headers.get('Authorization'));
      else if (headers.Authorization) capture(headers.Authorization);
      else if (headers.authorization) capture(headers.authorization);
    }
    if (input && input.headers && typeof input.headers.get === 'function') capture(input.headers.get('Authorization'));
    return originalFetch.apply(this, arguments);
  };
  var originalSetRequestHeader = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
    if (String(name).toLowerCase() === 'authorization') capture(value);
    return originalSetRequestHeader.apply(this, arguments);
  };
})();
''';

  static const String _safeCustomerCaptureScript = r'''
(function() {
  if (window.__pcSmartMergeV3) return;
  window.__pcSmartMergeV3 = true;
  console.log("🔔 [INTERCEPTOR INIT] Smart Merge Interceptor v3.0 Active!");
  var customerCache = {};
  function dispatchToFlutter(sourceTag, payload) {
    try {
      console.log("🚀 [JS STEP 4] (" + sourceTag + ") Sending Merged Payload:", JSON.stringify(payload));
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', payload).catch(function(err) { console.log("❌ [JS STEP 5 ERR]:", String(err)); });
      }
    } catch (error) { console.log("❌ [JS DISPATCH EXCEPTION]:", String(error)); }
  }
  var origFetch = window.fetch;
  window.fetch = async function() {
    var response = await origFetch.apply(this, arguments);
    try {
      var input = arguments[0], urlStr = String(input && input.url || input || '');
      var isVerify = urlStr.indexOf('/verify-nik') !== -1 || urlStr.indexOf('nationalityId=') !== -1;
      var isQuota = urlStr.indexOf('/customers/') !== -1 && urlStr.indexOf('/quota') !== -1;
      if (!isVerify && !isQuota) return response;
      var match = urlStr.match(/\b\d{16}\b/), nik = match ? String(match[0]) : '';
      if (nik.length !== 16) return response;
      response.clone().json().then(function(data) {
        var body = data && data.data || data || {};
        var existing = customerCache[nik] || {nik: nik, nama: 'Pelanggan ' + nik, familyId: '', category: 'Rumah Tangga', remainingQuota: 0, isEnriched: 1};
        if (isVerify) {
          var realName = String(body.name || body.nama || '').trim();
          var familyId = String(body.familyIdEncrypted || body.familyId || '').trim();
          if (realName) existing.nama = realName;
          if (familyId) existing.familyId = familyId;
          dispatchToFlutter('VERIFY_NIK_MERGE', existing);
        } else {
          var quota = body.quotaRemaining || {};
          var parsedQuota = Number(quota.monthly !== undefined ? quota.monthly : quota.family);
          existing.remainingQuota = Number.isFinite(parsedQuota) ? parsedQuota : 0;
          dispatchToFlutter('QUOTA_MERGE', existing);
        }
        customerCache[nik] = existing;
      }).catch(function(error) { console.log('[JS JSON ERROR]', String(error)); });
    } catch (error) { console.log("❌ [JS GLOBAL FETCH ERROR]:", String(error)); }
    return response;
  };
})();
''';
  static const String _diagnosticCustomerCaptureScript = r'''
(function() {
  if (window.__pcDiagnosticCustomerCapture) return;
  window.__pcDiagnosticCustomerCapture = true;
  console.log('[INTERCEPTOR INIT] Interceptor dengan Global Error Logger Aktif!');
  window.onerror = function(message, source, line, column, error) {
    console.log('[GLOBAL JS ERROR]: ' + String(message) + ' at ' + line + ':' + column);
    return false;
  };
  window.addEventListener('unhandledrejection', function(event) {
    var reason = event && event.reason || '';
    var text = String(reason && reason.message || reason);
    if (text.indexOf('Firebase') < 0 && text.indexOf('messaging') < 0) {
      console.log('[UNHANDLED PROMISE REJECTION]: ' + text);
    }
  });
  function safeDispatch(tag, payload, attempt) {
    attempt = attempt || 1;
    try {
      console.log('[JS STEP 4] (' + tag + ') Percobaan ' + attempt);
      if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
        window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', payload)
          .then(function() { console.log('[JS STEP 5 SUCCESS] Flutter Handler merespon'); })
          .catch(function(error) { console.log('[JS STEP 5 ERROR]', String(error)); });
      } else if (attempt < 10) {
        console.log('[JS STEP 4 WAITING] Bridge belum siap');
        setTimeout(function() { safeDispatch(tag, payload, attempt + 1); }, 300);
      } else console.log('[JS STEP 4 FAIL] Bridge tidak tersedia setelah 10 percobaan');
    } catch (error) { console.log('[JS DISPATCH EXCEPTION]', String(error)); }
  }
  var originalFetch = window.fetch;
  window.fetch = async function() {
    var response = await originalFetch.apply(this, arguments);
    try {
      var input = arguments[0], url = input && input.url || input || '';
      url = String(url);
      if (url.indexOf('/customers/') < 0 && url.indexOf('/verify-nik') < 0 && url.indexOf('/quota') < 0 && url.indexOf('nationalityId=') < 0) return response;
      return response;
    } catch (error) { console.log('[JS GLOBAL FETCH ERROR]', String(error)); }
    return response;
  };
})();
''';

  static const String _retryBridgeOnLoadStopScript = r'''
(function() {
  if (window.__pcRetryBridgeV2) return;
  window.__pcRetryBridgeV2 = true;
  console.log('[INTERCEPTOR INIT] Interceptor v2.0 dengan Retry Bridge Aktif!');
  window.__pcDispatchWithRetry = function(payload, attempt) {
    attempt = attempt || 1;
    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === 'function') {
      console.log('[JS STEP 4] Memanggil callHandler Percobaan ' + attempt, JSON.stringify(payload));
      window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', payload)
        .then(function() { console.log('[JS STEP 5 SUCCESS] Flutter Handler Berhasil Merespon'); })
        .catch(function(error) { console.log('[JS STEP 5 ERROR]', String(error)); });
    } else if (attempt < 10) {
      console.log('[JS STEP 4 WAITING] Bridge belum siap (' + attempt + '/10)');
      setTimeout(function() { window.__pcDispatchWithRetry(payload, attempt + 1); }, 300);
    } else console.log('[JS STEP 4 FAIL] Bridge tidak tersedia setelah 10 percobaan');
  };
})();
''';

  static const String _dataCaptureScript = r'''
(function() {
  if (window.__pcDataCapture) return;
  window.__pcDataCapture = true;
  function target(url) {
    return url && (String(url).indexOf('/general/v3/customers/verify') >= 0 ||
      String(url).indexOf('/general/v3/transactions') >= 0);
  }
  function forward(url, response) {
    if (!target(url) || !response || (response.status !== 200 && response.status !== 201)) return;
    response.clone().json().then(function(data) {
      if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler('onMyPertaminaDataCaptured', data);
    }).catch(function() {});
  }
  var fetchOriginal = window.fetch;
  window.fetch = function(input, init) {
    var promise = fetchOriginal.apply(this, arguments);
    promise.then(function(response) { forward(input && input.url || input, response); }).catch(function() {});
    return promise;
  };
  var xhrOpen = XMLHttpRequest.prototype.open;
  var xhrSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) { this.__pcCaptureUrl = url; return xhrOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener('load', function() {
      if (!target(this.__pcCaptureUrl) || (this.status !== 200 && this.status !== 201)) return;
      try { window.flutter_inappwebview.callHandler('onMyPertaminaDataCaptured', JSON.parse(this.responseText)); } catch (_) {}
    });
    return xhrSend.apply(this, arguments);
  };
})();
''';

  static const String _autofillFocusListenerScript = '''
(function() {
  if (window.autofillListenerAttached) return;
  window.autofillListenerAttached = true;
  let lastRequestAt = 0;
  function requestSuggestions(e) {
    const target = e.target;
    if (target && target.tagName === 'INPUT' &&
        (target.type === 'text' || target.type === 'password' ||
         target.name === 'username' || target.name === 'password')) {
      const now = Date.now();
      if (now - lastRequestAt < 300) return;
      lastRequestAt = now;
      if (window.flutter_inappwebview) window.flutter_inappwebview.callHandler('onRequestAccountSuggestions');
    }
  }
  document.addEventListener('focusin', requestSuggestions);
  document.addEventListener('click', requestSuggestions);
})();
''';

  static const String _manualLoginListenerScript = '''
(function() {
  if (window.__pcManualLoginListener) return;
  window.__pcManualLoginListener = true;
  const loginBtn = document.querySelector('button[type="submit"]') || document.querySelector('.btn-login');
  if (loginBtn) {
    loginBtn.addEventListener('click', function() {
      const userInput = document.querySelector('input[type="text"]') || document.querySelector('input[name="username"]');
      const passInput = document.querySelector('input[type="password"]') || document.querySelector('input[name="password"]');
      if (userInput && passInput && window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onManualLoginAttempt', userInput.value, passInput.value);
      }
    });
  }
})();
''';

  static const String _profileNameScript = '''
(function() {
  const profileNameEl = document.querySelector('.merchant-name') || document.querySelector('.user-profile-name') || document.querySelector('h4');
  return profileNameEl ? profileNameEl.innerText.trim() : 'Pangkalan MyPertamina';
})();
''';

  static const String _transactionBridgeScript = r'''
(function() {
  if (window.__pcTransactionBridge) return;
  window.__pcTransactionBridge = true;
  console.log('🌐 [WEBVIEW JS] Interceptor aktif & mendengarkan Fetch/XHR request...');
  function isStatic(url) { return /\\.(css|js|png|jpg|svg|woff)(\\?|$)/i.test(String(url || '')); }
  function forward(method, url, body, status, contentType, requestBody) {
    console.log('🌐 [WEBVIEW API CALL] Request URL: ' + url + ' | Status: ' + status);
    if (!url || isStatic(url) || !body || (status !== 200 && status !== 201)) return;
    var isApi = String(url).indexOf('api-map.my-pertamina.id') >= 0;
    if (!isApi && String(contentType || '').toLowerCase().indexOf('application/json') < 0) return;
    try {
      var parsed = typeof body === 'string' ? JSON.parse(body) : body;
      var jsonString = JSON.stringify(parsed);
      if ((url.indexOf('/general/v5/customers/') >= 0 && url.indexOf('/quota') >= 0) || url.indexOf('/general/customer-service/v1/verify-nik') >= 0 || url.indexOf('/customers/v2/verify-nik') >= 0) {
         console.log('🔍 [JS STEP 1] URL Quota/Verify Terdeteksi:', url);
         console.log('🔍 [JS STEP 2] Response JSON Diterima:', JSON.stringify(parsed));
         var parsedUrl = new URL(url, window.location.href);
         var customerMatch = parsedUrl.pathname.match(/(?:customers\/|verify-nik\/)([0-9]{16})/);
         var nik = '';
         try {
           var pathParts = url.split('/customers/');
           if (pathParts.length > 1) nik = pathParts[1].split('/quota')[0].trim();
         } catch (e) {}
         nik = nik || (customerMatch && customerMatch[1]) || parsedUrl.searchParams.get('nationalityId') || parsedUrl.searchParams.get('nik') || '';
          console.log('🔍 [JS STEP 3] Extracted NIK:', nik);

         if (!/^[0-9]{16}\$/.test(nik) && parsed && parsed.data) nik = parsed.data.nationalityId || parsed.data.nik || '';
         if (/^[0-9]{16}\$/.test(nik)) {
           var customer = parsed.data || parsed;
           var capturedCustomer = { nik: nik, familyId: parsedUrl.searchParams.get('familyId') || customer.familyId || '', category: parsedUrl.searchParams.get('customerType') || customer.customerType || 'Rumah Tangga', name: customer.name || customer.customerName || '', remainingQuota: customer.remainingQuota || 0, address: customer.address || '', phoneNumber: customer.phoneNumber || '' };
           console.log("📦 [JS CAPTURED CUSTOMER]:", JSON.stringify(capturedCustomer));
           window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', capturedCustomer);
         }
         return;
       }
       if (url.indexOf('/general/v5/customers/') >= 0 && url.indexOf('/quota') >= 0 && String(method).toUpperCase() === 'GET') {
         console.log('🔍 [JS STEP 1] URL Quota Terdeteksi:', url);
         console.log('🔍 [JS STEP 2] Response JSON Diterima:', JSON.stringify(parsed));
         var nik = '';
         try { var nikMatch = url.match(/\\b\\d{16}\\b/); if (nikMatch && nikMatch[0]) nik = nikMatch[0]; }
         catch (e) { console.log('❌ [JS ERROR STEP 3 NIK]:', e && e.toString ? e.toString() : e); }
         console.log('🔍 [JS STEP 3] Extracted NIK:', nik);
         try {
           var familyId = '';
           var category = '';
           try { var urlObj = new URL(url, window.location.href); familyId = urlObj.searchParams.get('familyId') || ''; category = urlObj.searchParams.get('customerType') || ''; }
           catch (e) { console.log('⚠️ [JS URL PARSE WARNING]:', e && e.toString ? e.toString() : e); }
           var responseData = parsed && parsed.data ? parsed.data : parsed;
           var extractedName = 'Pelanggan ' + nik;
           var extractedQuota = 0;
           if (responseData && responseData.name) extractedName = responseData.name;
           if (responseData && typeof responseData.remainingQuota !== 'undefined') extractedQuota = responseData.remainingQuota;
           var payload = { nik: nik, familyId: familyId, category: category || 'Rumah Tangga', name: extractedName, remainingQuota: extractedQuota, isEnriched: 1 };
           console.log('🔍 [JS STEP 4] Payload Siap Dikirim ke Flutter:', JSON.stringify(payload));
           if (nik && nik.length === 16) {
             if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
               window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', payload);
               console.log("✅ [JS STEP 5] Handler 'onMyPertaminaCustomerCaptured' BERHASIL DIPANGGIL!");
             } else console.log('❌ [JS ERROR STEP 5] window.flutter_inappwebview.callHandler TIDAK TERSEDIA!');
           } else console.log('⚠️ [JS CANCELLED] NIK tidak valid / panjang bukan 16 digit:', nik);
         } catch (postStep3Error) {
           console.log('❌ [JS CRITICAL ERROR AFTER STEP 3]:', postStep3Error && postStep3Error.toString ? postStep3Error.toString() : postStep3Error, postStep3Error && postStep3Error.stack ? postStep3Error.stack : '');
         }
         return;


        var parsedUrl = new URL(url, window.location.href);
        var customerMatch = parsedUrl.pathname.match(/\/customers\/([0-9]{16})\/quota/);
        if (customerMatch) {
          var captured = {
            nik: customerMatch[1],
            familyId: (function() { var raw = ''; try { raw = parsedUrl.searchParams.get('familyId') || ''; } catch (e) { console.log('⚠️ [JS URL PARSE FALLBACK]:', e && e.message ? e.message : e); } try { return raw ? decodeURIComponent(raw) : ''; } catch (e) { console.log('⚠️ [JS FAMILY ID DECODE FALLBACK]:', e && e.message ? e.message : e); return raw; } })(),
            category: parsedUrl.searchParams.get('customerType') || 'Rumah Tangga',
            name: parsed && parsed.data ? parsed.data.name || '' : '',
            remainingQuota: parsed && parsed.data ? parsed.data.remainingQuota || 0 : 0,
            rawResponse: parsed
          };
          console.log('📦 [WEBVIEW V5 QUOTA]: ' + JSON.stringify(captured));
          window.flutter_inappwebview.callHandler('onMyPertaminaCustomerCaptured', captured);
        }
        return;
      }
      if (String(method).toUpperCase() !== 'POST' ||
          (url.indexOf('/general/v2/transactions') < 0 && url.indexOf('/general/v3/transactions') < 0 && url.indexOf('/sale/pay-cash') < 0)) return;
      console.log('📦 [WEBVIEW CAPTURED PAYLOAD]: ' + jsonString);
      window.flutter_inappwebview.callHandler('onMyPertaminaTransactionCaptured', jsonString);
    } catch (error) { console.log('❌ [WEBVIEW INTERCEPTOR ERROR]: ' + error); }
  }
  const originalFetch = window.fetch;
  window.fetch = function(input) {
    var method = (arguments[1] && arguments[1].method) || (input && input.method) || 'GET';
    return originalFetch.apply(this, arguments).then(function(response) {
      const clone=response.clone();
      var contentType = response.headers && response.headers.get('content-type');
      clone.text().then(function(body){ forward(method, response.url, body, response.status, contentType); });
      return response;
    });
  };
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) { this.__pcMethod=method; this.__pcUrl=url; return originalOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() { this.__pcRequestBody=arguments[0]; this.addEventListener('load', function(){ forward(this.__pcMethod, this.__pcUrl, this.responseText, this.status, this.getResponseHeader('content-type'), this.__pcRequestBody); }); return originalSend.apply(this, arguments); };
})();
''';

  Future<void> _handleTokenCaptured(String token) async {
    if (_tokenCaptured) return;
    final auth = context.read<AuthProvider>();
    await auth.onTokenCaptured(token);
    if (!mounted) return;
    setState(() => _tokenCaptured = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _extractToken(Map<String, String>? headers) {
    if (headers == null || _tokenCaptured) return;

    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization' &&
          entry.value.startsWith('Bearer ')) {
        final token = entry.value.substring(7).trim();
        if (token.isNotEmpty) {
          _handleTokenCaptured(token);
          break;
        }
      }
    }
  }
}
