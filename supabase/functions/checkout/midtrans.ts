const MIDTRANS_SERVER_KEY =
    Deno.env.get("MIDTRANS_SERVER_KEY")!;

const MIDTRANS_CLIENT_KEY =
    Deno.env.get("MIDTRANS_CLIENT_KEY")!;

const MIDTRANS_IS_PRODUCTION =
    Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";

const MIDTRANS_BASE_URL = MIDTRANS_IS_PRODUCTION
    ? "https://api.midtrans.com"
    : "https://api.sandbox.midtrans.com";

export {
    MIDTRANS_SERVER_KEY,
    MIDTRANS_CLIENT_KEY,
    MIDTRANS_IS_PRODUCTION,
    MIDTRANS_BASE_URL,
};

async function createMidtransTransaction(payload: unknown) {
    const authString = btoa(`${MIDTRANS_SERVER_KEY}:`);

    const response = await fetch(
        `${MIDTRANS_BASE_URL}/v2/charge`,
        {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Basic ${authString}`,
            },
            body: JSON.stringify(payload),
        },
    );

    const data = await response.json();

    return {
        ok: response.ok,
        status: response.status,
        data,
    };
}

export {
    createMidtransTransaction,
};