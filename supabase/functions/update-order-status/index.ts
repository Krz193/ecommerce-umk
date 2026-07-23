import {serve} from "https://deno.land/std@0.224.0/http/server.ts";
import {createClient} from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
    try {
        /**
         * Supabase Flutter functions.invoke sends POST by default.
         * PATCH is still accepted for direct API clients.
         */
        if (!["POST", "PATCH"].includes(req.method)) {
            return new Response(JSON.stringify({error: "Method not allowed"}), {
                status: 405,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Supabase authenticated client
         *
         * Authorization handled via RLS.
         */
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL")!,
            Deno.env.get("SUPABASE_ANON_KEY")!,
            {
                global: {
                    headers: {
                        Authorization: req
                            .headers
                            .get("Authorization")!
                    }
                }
            },
        );

        /**
         * Validate authenticated user
         */
        const {data: {
                user
            }, error: authError} = await supabase
            .auth
            .getUser();

        if (authError || !user) {
            return new Response(JSON.stringify({error: "Unauthorized"}), {
                status: 401,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Parse request body
         */
        const body = await req.json();

        const {
            order_id,
            status,
            shipping_provider,
            tracking_number
        } = body;

        /**
         * Required payload validation
         */
        if (!order_id || !status) {
            return new Response(JSON.stringify({error: "Invalid payload"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Allowed operational statuses
         */
        const allowedStatuses = ["shipped", "completed"];

        if (!allowedStatuses.includes(status)) {
            return new Response(JSON.stringify({error: "Invalid status"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Load current order state
         */
        const {data: order, error: orderError} = await supabase
            .from("orders")
            .select(`
                *
            `)
            .eq("id", order_id)
            .single();

        console.log("Operational order:", order);

        if (orderError) {
            console.error(orderError);

            return new Response(JSON.stringify({error: "Order not found"}), {
                status: 404,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        const updates: Record<string, unknown> = {status};

        /**
         * Prepare lifecycle timestamps
         */
        let shippedAt = order.shipped_at;

        let completedAt = order.completed_at;

        if (status === "shipped") {
            if (order.status !== "processing") {
                return new Response(
                    JSON.stringify({error: "Invalid order lifecycle transition"}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            if (order.payment_status !== "paid") {
                return new Response(
                    JSON.stringify({error: "Only paid orders can be shipped"}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            const shippingProvider = String(shipping_provider ?? "").trim();
            const trackingNumber = String(tracking_number ?? "").trim();

            if (!shippingProvider || !trackingNumber) {
                return new Response(
                    JSON.stringify({error: "Shipping provider and tracking number are required"}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            const {error: storeOwnerError} = await supabase
                .from("stores")
                .select("id")
                .eq("id", order.store_id)
                .eq("owner_id", user.id)
                .single();

            if (storeOwnerError) {
                return new Response(JSON.stringify({error: "Forbidden"}), {
                    status: 403,
                    headers: {
                        "Content-Type": "application/json"
                    }
                },);
            }

            shippedAt = new Date().toISOString();
            updates.shipped_at = shippedAt;
            updates.shipping_provider = shippingProvider;
            updates.tracking_number = trackingNumber;
        }

        if (status === "completed") {
            if (order.status !== "shipped" || order.user_id !== user.id) {
                return new Response(
                    JSON.stringify({error: "Invalid order lifecycle transition"}),
                    {
                        status: 400,
                        headers: {
                            "Content-Type": "application/json"
                        }
                    },
                );
            }

            completedAt = new Date().toISOString();
            updates.completed_at = completedAt;
        }

        /**
         * Update operational order state
         */
        const {data: updatedOrder, error: updatedOrderError} = await supabase
            .from(
                "orders"
            )
            .update(updates)
            .eq("id", order.id)
            .select()
            .single();

        console.log("Updated operational order:", updatedOrder,);

        if (updatedOrderError) {
            console.error(updatedOrderError);

            return new Response(JSON.stringify({error: "Failed to update order"}), {
                status: 400,
                headers: {
                    "Content-Type": "application/json"
                }
            },);
        }

        /**
         * Success response
         */
        return new Response(JSON.stringify({success: true, order: updatedOrder}), {
            status: 200,
            headers: {
                "Content-Type": "application/json"
            }
        },);
    } catch (error) {
        console.error(error);

        return new Response(JSON.stringify({error: "Internal server error"}), {
            status: 500,
            headers: {
                "Content-Type": "application/json"
            }
        },);
    }
});
