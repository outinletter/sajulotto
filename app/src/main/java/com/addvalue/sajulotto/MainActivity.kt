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
import org.json.JSONArray
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

    private val DEEPSEEK_API_KEY = BuildConfig.DEEPSEEK_API_KEY

    @JavascriptInterface
    fun requestDeepSeekAI(prompt: String, callbackName: String) {
        CoroutineScope(Dispatchers.IO).launch {
            val result = try {
                callDeepSeekAPI(prompt)
            } catch (e: Exception) {
                "Error: ${e.message}"
            }
            withContext(Dispatchers.Main) {
                val escapedResult = result.replace("'", "\\'").replace("\n", "\\n")
                webView.evaluateJavascript("javascript:$callbackName('$escapedResult')", null)
            }
        }
    }

    private fun callDeepSeekAPI(prompt: String): String {
        if (DEEPSEEK_API_KEY.isEmpty()) {
            return "API 키가 설정되지 않았습니다. local.properties에서 API 키를 설정해주세요."
        }

        val url = URL("https://api.deepseek.com/v1/chat/completions")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Authorization", "Bearer $DEEPSEEK_API_KEY")
        conn.doOutput = true

        val jsonBody = JSONObject().apply {
            put("model", "deepseek-chat") // V3 모델 사용
            put("messages", JSONArray().apply {
                put(JSONObject().apply {
                    put("role", "system")
                    put("content", "당신은 사주 명리학 전문가이자 로또 번호 분석가입니다. 친절하고 신비로운 톤으로 답변하세요.")
                })
                put(JSONObject().apply {
                    put("role", "user")
                    put("content", prompt)
                })
            })
            put("temperature", 0.7)
            put("max_tokens", 1000) // 출력 길이 제한으로 비용 절감
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
            "API 호출 실패: ${conn.responseCode} ${conn.responseMessage}"
        }
    }
}
