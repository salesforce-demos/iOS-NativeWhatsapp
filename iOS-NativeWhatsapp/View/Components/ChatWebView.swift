import SwiftUI
import WebKit

final class ChatWebController: ObservableObject {
    @Published var isLoading = true
    @Published var lastError: String? = nil

    var dayLabel: String = "Today"
    var topGapPoints: CGFloat = 146
    var keyboardEventName: String = "keyboard_nextgen_chat"

    fileprivate weak var webView: WKWebView?

    func sendMessage() {
        evaluate("window.dispatchEvent(new CustomEvent('send_msg_nextgen_chat', { detail: { action: 'send' } }));")
    }

    func sendMessageSimple() {
        evaluate("window.dispatchEvent(new CustomEvent('send_msg_nextgen_chat'));")
    }

    func sendKeyboard(height: CGFloat, duration: Double, screenHeight: CGFloat) {
        let visible = height > 1
        let js = """
        (function(){
          var detail = { visible: \(visible), height: \(Int(height)), duration: \(duration),
                         screenHeight: \(Int(screenHeight)), unit: 'pt' };
          document.documentElement.style.setProperty('--keyboard-height', detail.height + 'px');
          document.documentElement.style.setProperty('--keyboard-visible', detail.visible ? '1' : '0');
          window.__nativeKeyboard = detail;
          window.dispatchEvent(new CustomEvent('\(keyboardEventName)', { detail: detail }));
        })();
        """
        evaluate(js)
    }

    func reload() {
        lastError = nil
        webView?.reload()
    }

    func resetToTop() {
        evaluate(Self.resetToTopScript)
        for delay in [0.2, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.evaluate(Self.resetToTopScript)
            }
        }
    }

    private static let resetToTopScript = """
    (function(){
      function deep(root, out){
        var els = root.querySelectorAll('*');
        for (var i = 0; i < els.length; i++) {
          out.push(els[i]);
          if (els[i].shadowRoot) deep(els[i].shadowRoot, out);
        }
      }
      var all = [];
      deep(document, all);
      for (var i = 0; i < all.length; i++) {
        if (all[i].scrollTop) { all[i].scrollTop = 0; }
      }
      if (document.scrollingElement) { document.scrollingElement.scrollTop = 0; }
      window.scrollTo(0, 0);
      window.__waPadPx = null;
      if (window.__waEnsure) { window.__waEnsure(); }
    })();
    """

    func scrollToBottom() {
        evaluate(Self.scrollToBottomScript)
        for delay in [0.25, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.evaluate(Self.scrollToBottomScript)
            }
        }
    }

    private static let scrollToBottomScript = """
    (function(){
      function deep(root, out){
        var els = root.querySelectorAll('*');
        for (var i = 0; i < els.length; i++) {
          out.push(els[i]);
          if (els[i].shadowRoot) deep(els[i].shadowRoot, out);
        }
      }
      var all = [];
      deep(document, all);
      for (var i = 0; i < all.length; i++) {
        var e = all[i];
        if (e.scrollHeight - e.clientHeight > 4) { e.scrollTop = e.scrollHeight; }
      }
      if (document.scrollingElement) {
        document.scrollingElement.scrollTop = document.scrollingElement.scrollHeight;
      }
      var c = window.__waChatContainer;
      if (c && c.lastElementChild && c.lastElementChild.scrollIntoView) {
        c.lastElementChild.scrollIntoView({ block: 'end' });
      }
    })();
    """

    private func evaluate(_ js: String) {
        guard let webView else { return }
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                print("ChatWebView JS error: \(error.localizedDescription)")
            }
        }
    }
}

final class ChatWebCache {
    static let shared = ChatWebCache()

    private var views: [URL: WKWebView] = [:]

    private init() {}

    func view(for url: URL) -> WKWebView {
        if let existing = views[url] { return existing }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        for moment in [WKUserScriptInjectionTime.atDocumentStart, .atDocumentEnd] {
            configuration.userContentController.addUserScript(
                WKUserScript(source: ChatWebView.noTextAutosizingScript, injectionTime: moment, forMainFrameOnly: true)
            )
        }

        let webView = WKWebView(
            frame: CGRect(origin: .zero, size: UIScreen.main.bounds.size),
            configuration: configuration
        )
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.overrideUserInterfaceStyle = .light

        views[url] = webView
        return webView
    }

    func preload(_ url: URL) {
        let webView = view(for: url)
        park(webView)
        if webView.url == nil, !webView.isLoading {
            webView.load(URLRequest(url: url))
        }
    }

    func refresh(_ url: URL) {
        guard let webView = views[url] else { return }
        park(webView)
        webView.reload()
    }

    func park(_ webView: WKWebView) {
        guard webView.superview == nil else { return }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window else { return }

        let reserved = WA.inputRowHeight + window.safeAreaInsets.bottom
        webView.frame = CGRect(
            x: 0,
            y: 0,
            width: window.bounds.width,
            height: max(1, window.bounds.height - reserved)
        )
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        window.insertSubview(webView, at: 0)
    }
}

struct ChatWebView: UIViewRepresentable {
    let url: URL
    let controller: ChatWebController

    func makeUIView(context: Context) -> WKWebView {
        let webView = ChatWebCache.shared.view(for: url)
        webView.navigationDelegate = context.coordinator
        webView.alpha = 1
        webView.isUserInteractionEnabled = true

        controller.webView = webView
        context.coordinator.loadedURL = url

        if webView.url == nil, !webView.isLoading {
            webView.load(URLRequest(url: url))
        } else if !webView.isLoading {
            controller.isLoading = false
            context.coordinator.injectChatHeader(in: webView)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        controller.webView = webView
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        ChatWebCache.shared.park(webView)
    }

    static let noTextAutosizingScript = """
    (function(){
      var css = 'html,body{-webkit-text-size-adjust:100% !important;text-size-adjust:100% !important;}'
              + 'html{background:transparent !important;}';
      var style = document.createElement('style');
      style.setAttribute('data-wa-no-autosize', '1');
      style.appendChild(document.createTextNode(css));
      (document.head || document.documentElement).appendChild(style);
    })();
    """

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, url: url)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let controller: ChatWebController
        var loadedURL: URL

        init(controller: ChatWebController, url: URL) {
            self.controller = controller
            self.loadedURL = url
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            controller.isLoading = true
            controller.lastError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            controller.isLoading = false
            injectChatHeader(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            controller.isLoading = false
            controller.lastError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            controller.isLoading = false
            controller.lastError = error.localizedDescription
        }

        func injectChatHeader(in webView: WKWebView) {
            let widthInPoints = webView.bounds.width > 1 ? webView.bounds.width : UIScreen.main.bounds.width
            let js = Self.headerScript(
                dayLabel: controller.dayLabel,
                widthInPoints: widthInPoints,
                topGapPoints: controller.topGapPoints
            )
            webView.evaluateJavaScript(js) { _, error in
                if let error {
                    print("ChatWebView inject error: \(error.localizedDescription)")
                }
            }
        }

        static func headerScript(dayLabel: String, widthInPoints: CGFloat, topGapPoints: CGFloat) -> String {
            let day = dayLabel.replacingOccurrences(of: "'", with: "\\'")
            return """
            (function(){
              var ID = 'wa-native-chat-header';
              var K = window.innerWidth / \(Int(widthInPoints));
              function px(v){ return Math.round(v * K) + 'px'; }
              var TOP_GAP = \(Int(topGapPoints));

              function build(){
                var wrap = document.createElement('div');
                wrap.id = ID;
                wrap.setAttribute('style',
                  'display:flex;flex-direction:column;align-items:center;width:100%;' +
                  'box-sizing:border-box;padding:0 0 ' + px(8) + ';' +
                  'font-family:-apple-system,BlinkMacSystemFont,system-ui,sans-serif;' +
                  'pointer-events:none;flex:none;');

                var note = document.createElement('div');
                note.setAttribute('style',
                  'background:#FBF0D6;border-radius:' + px(10) + ';' +
                  'margin:' + px(11) + ' ' + px(54) + ' 0;' +
                  'padding:' + px(8) + ' ' + px(14) + ';font-size:' + px(12) + ';' +
                  'line-height:' + px(18) + ';color:#0D0D0D;text-align:center;');
                note.innerHTML =
                  '<svg width="' + px(10) + '" height="' + px(12) + '" viewBox="0 0 10 12" ' +
                  'style="vertical-align:' + px(-1) + '"><path fill="#0D0D0D" d="M5 0a3 3 0 0 0-3 3v1H1.5A1.5 1.5 0 0 0 0 5.5v5A1.5 1.5 0 0 0 1.5 12h7A1.5 1.5 0 0 0 10 10.5v-5A1.5 1.5 0 0 0 8.5 4H8V3a3 3 0 0 0-3-3zm0 1.5A1.5 1.5 0 0 1 6.5 3v1h-3V3A1.5 1.5 0 0 1 5 1.5z"/></svg>' +
                  ' Messages and calls are end-to-end encrypted. ' +
                  'Only people in this chat can read, listen to, or share them. ' +
                  '<b>Learn more</b>';

                wrap.appendChild(note);
                return wrap;
              }

              function deepAll(){
                var out = [];
                (function walk(root){
                  var els = root.querySelectorAll('*');
                  for (var i = 0; i < els.length; i++) {
                    out.push(els[i]);
                    if (els[i].shadowRoot) walk(els[i].shadowRoot);
                  }
                })(document);
                return out;
              }
              function pageNotice(){
                var all = deepAll(), best = null;
                for (var i = 0; i < all.length; i++) {
                  var t = all[i].textContent || '';
                  if (t.indexOf('end-to-end encryption') >= 0) {
                    if (!best || t.length < (best.textContent || '').length) best = all[i];
                  }
                }
                return best;
              }
              function ensure(){
                var notice = pageNotice();
                if (!notice || !notice.parentNode) return false;
                var container = notice.parentNode;
                notice.style.display = 'none';

                window.__waChatContainer = container;
                var block = container.querySelector('#' + ID);
                if (!block) {
                  block = build();
                  container.insertBefore(block, container.firstChild);
                }
                block.style.paddingTop = px(TOP_GAP);
                if (!window.__waHeaderObserver) {
                  window.__waHeaderObserver = new MutationObserver(function(){ ensure(); });
                  window.__waHeaderObserver.observe(container, { childList: true, subtree: true });
                }
                return true;
              }
              window.__waEnsure = ensure;

              var tries = 0;
              (function tick(){
                if (ensure()) return;
                if (++tries < 80) setTimeout(tick, 250);
              })();

              return 'scheduled';
            })();
            """
        }
    }
}
