package com.addvalue.sajulotto

import android.annotation.SuppressLint
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import com.addvalue.sajulotto.ui.theme.SajuLottoTheme
import com.addvalue.sajulotto.BuildConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            SajuLottoTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    WebViewScreen(
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun WebViewScreen(modifier: Modifier = Modifier) {
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { context ->
            WebView(context).apply {
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    loadWithOverviewMode = true
                    useWideViewPort = true
                    builtInZoomControls = false
                    displayZoomControls = false
                    setSupportZoom(false)
                    defaultTextEncodingName = "UTF-8"
                }
                webViewClient = WebViewClient()
                webChromeClient = WebChromeClient()
                addJavascriptInterface(SajuBridge(this), "AndroidBridge")
                loadUrl("file:///android_asset/index.html")
            }
        }
    )
}

class SajuBridge(private val webView: WebView) {

    private val WORKER_URL = BuildConfig.WORKER_URL

    @JavascriptInterface
    fun requestDeepSeekAI(prompt: String, callbackName: String) {
        CoroutineScope(Dispatchers.IO).launch {
            val result = try {
                callWorkerAPI(prompt)
            } catch (e: Exception) {
                "Error: ${e.message}"
            }
            withContext(Dispatchers.Main) {
                val escapedResult = result.replace("'", "\\'").replace("\n", "\\n")
                webView.evaluateJavascript("javascript:$callbackName('$escapedResult')", null)
            }
        }
    }

    private fun callWorkerAPI(prompt: String): String {
        if (WORKER_URL.contains("your-worker-name")) {
            return "Cloudflare Worker URL이 설정되지 않았습니다. local.properties에서 WORKER_URL을 설정해주세요."
        }

        val url = URL(WORKER_URL)
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true

        val jsonBody = JSONObject().apply {
            put("prompt", prompt)
        }

        OutputStreamWriter(conn.outputStream).use { it.write(jsonBody.toString()) }

        return if (conn.responseCode == 200) {
            val response = conn.inputStream.bufferedReader().use { it.readText() }
            val jsonResponse = JSONObject(response)
            jsonResponse.getJSONArray("choices")
                .getJSONObject(0)
                .getJSONObject("message")
                .getString("content")
        } else {
            "Worker 호출 실패: ${conn.responseCode} ${conn.responseMessage}"
        }
    }
}
