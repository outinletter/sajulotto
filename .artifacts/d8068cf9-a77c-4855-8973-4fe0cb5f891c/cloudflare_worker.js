export default {
  async fetch(request, env) {
    // CORS 헤더 설정
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    };

    // OPTIONS 요청 처리 (CORS preflight)
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    try {
      const { prompt } = await request.json();

      // DeepSeek API 호출
      const response = await fetch("https://api.deepseek.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${env.DEEPSEEK_API_KEY}`
        },
        body: JSON.stringify({
          model: "deepseek-chat",
          messages: [
            {
              role: "system",
              content: "전달된 사주 계산 근거와 전통적 해석을 구분하여 설명하세요. 계산되지 않은 대운·용신·격국이나 당첨·질병·재정적 이익을 만들어 예측하지 마세요. 짧은 문단과 독립된 Markdown 제목으로 읽기 쉽게 작성하세요."
            },
            {
              role: "user",
              content: prompt
            }
          ],
          temperature: 0.3,
          max_tokens: 3500
        })
      });

      const data = await response.json();

      if (!response.ok) {
        return new Response(JSON.stringify({
          error: data.error || "DeepSeek API error",
          status: response.status
        }), {
          status: response.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" }
        });
      }

      return new Response(JSON.stringify(data), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
  }
};
