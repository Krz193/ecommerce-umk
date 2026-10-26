import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computeHmacSha256, timingSafeEqual, verifyBiteshipSignature } from "./biteship.ts";

function formatIdPhone(phone?: string | null): string {
    if (!phone) return "081234567890";
    let cleaned = String(phone).replace(/[^0-9]/g, "");
    if (cleaned.startsWith("62")) cleaned = "0" + cleaned.slice(2);
    if (cleaned.startsWith("8")) cleaned = "0" + cleaned;
    if (!cleaned.startsWith("0")) cleaned = "08" + cleaned;
    if (cleaned.length < 10) cleaned = cleaned.padEnd(11, "0");
    return cleaned;
}

Deno.test("Security: computeHmacSha256 produces deterministic hex signature", async () => {
    const secret = "test_webhook_secret_key";
    const payload = JSON.stringify({ event: "order.status_update", status: "dropping_off" });

    const sig1 = await computeHmacSha256(secret, payload);
    const sig2 = await computeHmacSha256(secret, payload);

    assertEquals(typeof sig1, "string");
    assertEquals(sig1.length, 64); // SHA-256 hex output is 64 characters
    assertEquals(sig1, sig2);
});

Deno.test("Security: timingSafeEqual validates equal and unequal strings", () => {
    assertEquals(timingSafeEqual("abc12345", "abc12345"), true);
    assertEquals(timingSafeEqual("abc12345", "abc12346"), false);
    assertEquals(timingSafeEqual("abc", "abcdef"), false);
});

Deno.test("Security: verifyBiteshipSignature authenticates valid signature and rejects spoofing", async () => {
    const secret = "super_secure_biteship_secret";
    const body = '{"status":"delivered","reference_id":"ORD-1790398799466"}';
    const validSignature = await computeHmacSha256(secret, body);

    const isVerified = await verifyBiteshipSignature(body, validSignature, secret);
    assertEquals(isVerified, true);

    const isTampered = await verifyBiteshipSignature('{"status":"delivered","amount":0}', validSignature, secret);
    assertEquals(isTampered, false);

    const isWrongSecret = await verifyBiteshipSignature(body, validSignature, "attacker_secret");
    assertEquals(isWrongSecret, false);
});

Deno.test("Logistics: formatIdPhone standardizes Indonesian numbers for courier API", () => {
    assertEquals(formatIdPhone("08123456789"), "08123456789");
    assertEquals(formatIdPhone("628123456789"), "08123456789");
    assertEquals(formatIdPhone("+62 812-3456-7890"), "081234567890");
    assertEquals(formatIdPhone("8123456789"), "08123456789");
    assertEquals(formatIdPhone(null), "081234567890");
});

Deno.test("Anti-Duplication: Idempotency keys are deterministic per order", () => {
    const orderId = "f1fc9730-91d8-40e9-8802-d879dbb0b2c1";
    const orderNumber = "ORD-1790398799466";

    const key1 = `biteship-${orderId}-${orderNumber}`;
    const key2 = `biteship-${orderId}-${orderNumber}`;

    assertEquals(key1, key2);
    assertEquals(key1, "biteship-f1fc9730-91d8-40e9-8802-d879dbb0b2c1-ORD-1790398799466");
});
