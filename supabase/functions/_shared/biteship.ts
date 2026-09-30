import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * [OBS-001] Centralized HTTP Logger for Biteship Requests & Responses
 * Logs URL, Method, Request Body, Status Code, Response Body, and Duration to database.
 */
export async function logBiteshipApiCall(
  supabase: SupabaseClient,
  params: {
    url: string;
    method: string;
    requestBody?: any;
    statusCode?: number;
    responseBody?: any;
    durationMs?: number;
    errorMessage?: string;
  }
) {
  try {
    await supabase.from("biteship_api_logs").insert({
      url: params.url,
      method: params.method,
      request_body: params.requestBody ? (typeof params.requestBody === "string" ? JSON.parse(params.requestBody) : params.requestBody) : null,
      status_code: params.statusCode ?? null,
      response_body: params.responseBody ? (typeof params.responseBody === "string" ? JSON.parse(params.responseBody) : params.responseBody) : null,
      duration_ms: params.durationMs ?? null,
      error_message: params.errorMessage ?? null,
    });
  } catch (err) {
    console.error("[OBS-001] Failed to record Biteship API log:", err);
  }
}

/**
 * [WHK-001] HMAC-SHA256 Signature Computation & Verification
 * Extracts signature header, re-computes HMAC with secret, and compares.
 */
export async function computeHmacSha256(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

export async function verifyBiteshipSignature(
  rawBody: string,
  signatureHeader: string | null,
  secretKey: string
): Promise<boolean> {
  if (!signatureHeader || !secretKey) {
    return false;
  }

  try {
    const computedSignature = await computeHmacSha256(secretKey, rawBody);
    return timingSafeEqual(computedSignature.toLowerCase(), signatureHeader.trim().toLowerCase());
  } catch (err) {
    console.error("[WHK-001] Webhook signature verification error:", err);
    return false;
  }
}

/**
 * [RES-001] Timeout Management for Rates API
 * Sets timeout (3000ms - 5000ms) with AbortController and TimeoutException handling.
 */
export class TimeoutException extends Error {
  constructor(message = "Request timed out") {
    super(message);
    this.name = "TimeoutException";
  }
}

export async function fetchWithTimeout(
  url: string,
  options: RequestInit,
  timeoutMs = 4000
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } catch (error: any) {
    if (error.name === "AbortError") {
      throw new TimeoutException(`HTTP Request to ${url} exceeded timeout of ${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

/**
 * [RES-002] Exponential Backoff Mechanism for Courier Requests & Sync
 * Automatically retries on 5xx or network errors with progressive delays (e.g. 2s, 4s, 8s).
 */
export async function fetchWithExponentialBackoff(
  url: string,
  options: RequestInit,
  delays: number[] = [2000, 4000, 8000],
  supabase?: SupabaseClient
): Promise<Response> {
  let lastError: Error | null = null;
  const startTime = Date.now();

  for (let attempt = 0; attempt <= delays.length; attempt++) {
    try {
      const response = await fetch(url, options);

      // Retry on HTTP 5xx Server Errors
      if (response.status >= 500 && attempt < delays.length) {
        const delay = delays[attempt];
        console.warn(
          `[RES-002] Biteship API returned HTTP ${response.status}. Retrying attempt ${attempt + 1}/${delays.length} in ${delay}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
        continue;
      }

      return response;
    } catch (err: any) {
      lastError = err;
      if (attempt < delays.length) {
        const delay = delays[attempt];
        console.warn(
          `[RES-002] Network error: ${err.message}. Retrying attempt ${attempt + 1}/${delays.length} in ${delay}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  if (supabase) {
    await logBiteshipApiCall(supabase, {
      url,
      method: options.method || "GET",
      requestBody: options.body,
      statusCode: 500,
      durationMs: Date.now() - startTime,
      errorMessage: `Exponential backoff exhausted after ${delays.length} retries: ${lastError?.message}`,
    });
  }

  throw lastError || new Error(`[RES-002] Request failed after ${delays.length} retries with exponential backoff`);
}

/**
 * [FIN-002] Critical Balance Notification System
 * Detects insufficient balance and sends alerts to Slack/Telegram/Email.
 */
export async function notifyCriticalBalance(details: {
  currentBalance?: number;
  threshold?: number;
  orderId?: string;
  errorMessage?: string;
}) {
  const message = `🚨 [CRITICAL ALERT] Biteship Insufficient / Critical Balance Detected!
- Order Reference: ${details.orderId || "N/A"}
- Current Balance: ${details.currentBalance !== undefined ? `Rp ${details.currentBalance.toLocaleString("id-ID")}` : "Insufficient"}
- Threshold: Rp ${(details.threshold || 50000).toLocaleString("id-ID")}
- Error: ${details.errorMessage || "Account balance is insufficient for courier dispatch"}
- Timestamp: ${new Date().toISOString()}`;

  console.error(message);

  // 1. Slack Webhook integration
  const slackWebhookUrl = Deno.env.get("SLACK_WEBHOOK_URL");
  if (slackWebhookUrl) {
    try {
      await fetch(slackWebhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: message }),
      });
    } catch (e) {
      console.error("[FIN-002] Failed to dispatch Slack alert:", e);
    }
  }

  // 2. Telegram Bot integration
  const telegramBotToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  const telegramChatId = Deno.env.get("TELEGRAM_CHAT_ID");
  if (telegramBotToken && telegramChatId) {
    try {
      await fetch(`https://api.telegram.org/bot${telegramBotToken}/sendMessage`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: telegramChatId,
          text: message,
          parse_mode: "Markdown",
        }),
      });
    } catch (e) {
      console.error("[FIN-002] Failed to dispatch Telegram alert:", e);
    }
  }

  // 3. Email Webhook notification
  const emailNotificationWebhook = Deno.env.get("ALERT_EMAIL_WEBHOOK_URL");
  if (emailNotificationWebhook) {
    try {
      await fetch(emailNotificationWebhook, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          subject: "[CRITICAL] Biteship Insufficient Balance",
          body: message,
        }),
      });
    } catch (e) {
      console.error("[FIN-002] Failed to dispatch Email alert:", e);
    }
  }
}
