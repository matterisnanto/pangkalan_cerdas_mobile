import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/secure_storage_service.dart';

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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackToDashboard != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBackToDashboard,
              )
            : null,
        title: const Text('Portal MyPertamina'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_tokenCaptured)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle, color: Colors.greenAccent),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadProgress / 100,
              backgroundColor: Colors.grey.shade300,
              color: Colors.blue.shade800,
            ),
          if (_tokenCaptured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Colors.green.shade700,
              child: const Text(
                'Token Bearer berhasil ditangkap!',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(
                  'https://subsiditepatlpg.mypertamina.id/merchant-login',
                ),
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
                    await SecureStorageService().saveToken(token);
                    if (!mounted) return;
                    setState(() => _tokenCaptured = true);
                    context.read<AuthProvider>().onTokenCaptured(token);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Token Bearer berhasil disimpan.'),
                      ),
                    );
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
              onProgressChanged: (controller, progress) {
                setState(() {
                  _loadProgress = progress.toDouble();
                  _isLoading = progress < 100;
                });
              },
              shouldInterceptRequest: (controller, request) async {
                _extractToken(request.headers, authProvider);
                return null;
              },
              onLoadResource: (controller, resource) {
                // Fallback token capture from load resource
              },
              onReceivedServerTrustAuthRequest: (controller, challenge) async {
                return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.PROCEED,
                );
              },
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

  static const String _transactionBridgeScript = '''
(function() {
  if (window.__pcTransactionBridge) return;
  window.__pcTransactionBridge = true;
  function forward(url, body) {
    if (!url || !body) return;
    if (url.indexOf('/general/v1/transactions/') < 0 && url.indexOf('/general/v2/transactions') < 0 && url.indexOf('/general/v3/transactions/report') < 0) return;
    try { var parsed = typeof body === 'string' ? JSON.parse(body) : body; window.flutter_inappwebview.callHandler('myPertaminaTransaction', parsed); } catch (_) {}
  }
  const originalFetch = window.fetch;
  window.fetch = function() { return originalFetch.apply(this, arguments).then(function(response) { const clone=response.clone(); clone.text().then(function(body){ forward(response.url, body); }); return response; }); };
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) { this.__pcUrl=url; return originalOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() { this.addEventListener('load', function(){ forward(this.__pcUrl, this.responseText); }); return originalSend.apply(this, arguments); };
})();
''';

  void _extractToken(Map<String, String>? headers, AuthProvider authProvider) {
    if (headers == null || _tokenCaptured) return;

    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization' &&
          entry.value.startsWith('Bearer ')) {
        final token = entry.value.substring(7).trim();
        if (token.isNotEmpty) {
          setState(() => _tokenCaptured = true);
          authProvider.onTokenCaptured(token);
          break;
        }
      }
    }
  }
}
