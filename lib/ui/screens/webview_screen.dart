import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

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
                url: WebUri('https://subsiditepatlpg.mypertamina.id/merchant-login'),
              ),
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
              },
              onLoadStop: (controller, url) async {
                if (url.toString() == 'https://subsiditepatlpg.mypertamina.id/' ||
                    url.toString() == 'https://subsiditepatlpg.mypertamina.id') {
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
