package cloud.hoststorm.storm_msn_mobile

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cloud.hoststorm.storm_msn_mobile/navigation"
        ).setMethodCallHandler { call, result ->
            if (call.method != "openBrowser") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val text = call.argument<String>("url") ?: ""
            val uri = Uri.parse(text)
            val allowed = uri.scheme == "https" && (
                uri.host == "msn.hoststorm.com.br" ||
                uri.host == "playstor.hoststorm.cloud"
            )
            if (!allowed) {
                result.error("DOMAIN_BLOCKED", "Domínio não autorizado.", null)
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
                result.success(null)
            } catch (_: Exception) {
                result.error("NO_BROWSER", "Nenhum navegador disponível.", null)
            }
        }
    }
}
