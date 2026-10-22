import 'dart:collection';
import 'dart:convert';

import '../../services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
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
        const inputs = document.querySelectorAll('input');
        inputs.forEach(input => {
          if (input.type === 'text' || input.name === 'username' || input.id === 'username') {
            input.value = $username;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if (input.type === 'password' || input.name === 'password' || input.id === 'password') {
            input.value = $password;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
          }
        });
      })();
    ''',
    );
    if (mounted) {
      _showTopNotification(
        'Data login [${account['name']}] berhasil diisikan!',
      );
    }
  }

  Future<void> _showAccountSuggestions() async {
    debugPrint('🔑 [AUTOFILL TRIGGERED] Kolom input login diklik di WebView');
    await _loadAccounts();
    if (!mounted) return;
    if (_accounts.isEmpty) {
      _showTopNotification(
        'Belum ada akun pangkalan tersimpan. Tambahkan akun di Pengaturan untuk menggunakan fitur auto-fill.',
      );
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
      _showTopNotification(
        'Akun [$name] berhasil disimpan otomatis ke Pengaturan!',
      );
    }
  }

  void _showTopNotification(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: 10,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).size.height - 140,
        ),
        backgroundColor: const Color(0xFF00AA5B),
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
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
                    source: _tokenInterceptorScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: false,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  clearCache: false,
                  cacheEnabled: true,
                  sharedCookiesEnabled: true,
                  useShouldInterceptRequest: true,
                  useOnLoadResource: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  userAgent:
                      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
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
                    source: _transactionBridgeScript,
                  );
                  await controller.evaluateJavascript(
                    source:
                        "document.documentElement.style.paddingBottom = '120px';",
                  );
                  await _handleUrl(url, controller);
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
                onLoadResource: (controller, resource) {
                  // Fallback token capture from load resource
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
          if (_isMerchantLogin && _accounts.isNotEmpty)
            Positioned(
              top: 58,
              left: 12,
              right: 12,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, String>>(
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Pilih Pangkalan untuk Auto-Login'),
                        ),
                        items: _accounts
                            .map(
                              (account) => DropdownMenuItem(
                                value: account,
                                child: Text(account['name'] ?? 'Pangkalan'),
                              ),
                            )
                            .toList(),
                        onChanged: (account) {
                          if (account != null) _fillAccount(account);
                        },
                      ),
                    ),
                  ),
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

  static const String _autofillFocusListenerScript = '''
(function() {
  if (window.autofillListenerAttached) return;
  window.autofillListenerAttached = true;
  function requestSuggestions(e) {
    const target = e.target;
    if (target && (target.tagName === 'INPUT' || target.type === 'text' || target.type === 'password' || target.name === 'username')) {
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

  static const String _transactionBridgeScript = '''
(function() {
  if (window.__pcTransactionBridge) return;
  window.__pcTransactionBridge = true;
  function forward(method, url, body) {
    if (String(method).toUpperCase() !== 'POST' || !url || !body) return;
    if (url.indexOf('/general/v2/transactions') < 0 && url.indexOf('/general/v3/transactions') < 0) return;
    try {
      var parsed = typeof body === 'string' ? JSON.parse(body) : body;
      window.flutter_inappwebview.callHandler('myPertaminaTransaction', parsed);
    } catch (_) {}
  }
  const originalFetch = window.fetch;
  window.fetch = function(input) {
    var method = (arguments[1] && arguments[1].method) || (input && input.method) || 'GET';
    return originalFetch.apply(this, arguments).then(function(response) {
      const clone=response.clone();
      clone.text().then(function(body){ forward(method, response.url, body); });
      return response;
    });
  };
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) { this.__pcMethod=method; this.__pcUrl=url; return originalOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() { this.addEventListener('load', function(){ forward(this.__pcMethod, this.__pcUrl, this.responseText); }); return originalSend.apply(this, arguments); };
})();
''';

  Future<void> _handleTokenCaptured(String token) async {
    if (_tokenCaptured) return;
    final auth = context.read<AuthProvider>();
    await auth.onTokenCaptured(token);
    if (!mounted) return;
    setState(() => _tokenCaptured = true);
    final stock = auth.stockAvailable;
    final storeName = auth.storeName.isEmpty ? 'Pangkalan' : auth.storeName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$storeName Berhasil Terkoneksi - Stok: $stock Tabung'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) widget.onBackToDashboard?.call();
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
