-- Migration: Fix product_reviews join in recommendation metrics and auto-recommendation RPCs
-- product_reviews links to store via products.store_id, not product_reviews.store_id

CREATE OR REPLACE FUNCTION public.get_store_product_recommendation_metrics(p_store_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result json;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.stores
        WHERE id = p_store_id
          AND (
              owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants
                  WHERE store_id = p_store_id AND user_id = auth.uid()
              )
              OR EXISTS (
                  SELECT 1 FROM public.users u
                  WHERE u.id = auth.uid() AND u.role = 'admin'
              )
          )
    ) THEN
        RAISE EXCEPTION 'Unauthorized to view recommendation metrics for this store';
    END IF;

    SELECT coalesce(json_agg(
        json_build_object(
            'product_id', p.id,
            'product_name', p.name,
            'price', p.price,
            'original_price', coalesce(p.original_price, p.price),
            'discount_percent', coalesce(p.discount_percent, 0),
            'discount_amount', coalesce(p.discount_amount, 0),
            'stock', p.stock,
            'status', p.status,
            'thumbnail_url', p.thumbnail_url,
            'sold_qty', coalesce(sales.sold_qty, 0),
            'avg_rating', coalesce(rev.avg_rating, 0),
            'review_count', coalesce(rev.review_count, 0),
            'cart_qty', coalesce(crt.cart_qty, 0),
            'recommendation_id', pr.id,
            'is_recommended', (pr.id IS NOT NULL AND pr.is_active = true),
            'priority', coalesce(pr.priority, 0),
            'badge_text', pr.badge_text,
            'formula_score', coalesce(pr.formula_score, 0),
            'formula_mode', coalesce(pr.formula_mode, 'manual')
        ) ORDER BY coalesce(pr.priority, 0) DESC, p.created_at DESC
    ), '[]'::json)
    INTO v_result
    FROM public.products p
    LEFT JOIN (
        SELECT oi.product_id, sum(oi.quantity)::int AS sold_qty
        FROM public.order_items oi
        JOIN public.orders o ON o.id = oi.order_id
        WHERE o.store_id = p_store_id
          AND o.payment_status = 'paid'
          AND o.status NOT IN ('cancelled', 'failed')
        GROUP BY oi.product_id
    ) sales ON sales.product_id = p.id
    LEFT JOIN (
        SELECT r.product_id, round(avg(r.rating)::numeric, 2) AS avg_rating, count(*)::int AS review_count
        FROM public.product_reviews r
        JOIN public.products rp ON rp.id = r.product_id
        WHERE rp.store_id = p_store_id AND r.is_approved = true
        GROUP BY r.product_id
    ) rev ON rev.product_id = p.id
    LEFT JOIN (
        SELECT ci.product_id, sum(ci.quantity)::int AS cart_qty
        FROM public.cart_items ci
        JOIN public.products prod ON prod.id = ci.product_id
        WHERE prod.store_id = p_store_id
        GROUP BY ci.product_id
    ) crt ON crt.product_id = p.id
    LEFT JOIN public.product_recommendations pr ON pr.product_id = p.id
    WHERE p.store_id = p_store_id
      AND p.archived_at IS NULL;

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.apply_auto_store_recommendations(
    p_store_id UUID,
    p_top_n INT DEFAULT 3
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_max_sold NUMERIC := 1;
    v_max_cart NUMERIC := 1;
    v_max_stock NUMERIC := 1;
    v_rec RECORD;
    v_rank INT := 0;
    v_applied_count INT := 0;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Authorization check: store owner, store assistant, or admin
    IF NOT EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = p_store_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = p_store_id AND sa.user_id = auth.uid()
              )
              OR EXISTS (
                  SELECT 1 FROM public.users u
                  WHERE u.id = auth.uid() AND u.role = 'admin'
              )
          )
    ) THEN
        RAISE EXCEPTION 'Tidak memiliki akses untuk mengatur rekomendasi toko ini';
    END IF;

    -- Normalization denominators across store products
    SELECT
        GREATEST(COALESCE(MAX(COALESCE(sales.sold_qty, 0)), 1), 1),
        GREATEST(COALESCE(MAX(COALESCE(crt.cart_qty, 0)), 1), 1),
        GREATEST(COALESCE(MAX(COALESCE(p.stock, 0)), 1), 1)
    INTO v_max_sold, v_max_cart, v_max_stock
    FROM public.products p
    LEFT JOIN (
        SELECT oi.product_id, SUM(oi.quantity)::int AS sold_qty
        FROM public.order_items oi
        JOIN public.orders o ON o.id = oi.order_id
        WHERE o.store_id = p_store_id
          AND o.payment_status = 'paid'
          AND o.status NOT IN ('cancelled', 'failed')
        GROUP BY oi.product_id
    ) sales ON sales.product_id = p.id
    LEFT JOIN (
        SELECT ci.product_id, SUM(ci.quantity)::int AS cart_qty
        FROM public.cart_items ci
        JOIN public.products prod ON prod.id = ci.product_id
        WHERE prod.store_id = p_store_id
        GROUP BY ci.product_id
    ) crt ON crt.product_id = p.id
    WHERE p.store_id = p_store_id
      AND p.archived_at IS NULL;

    -- Reset current store recommendations before applying Top-N
    DELETE FROM public.product_recommendations
    WHERE product_id IN (
        SELECT id FROM public.products WHERE store_id = p_store_id
    );

    -- Score and rank products server-side
    FOR v_rec IN (
        SELECT
            p.id AS product_id,
            COALESCE(sales.sold_qty, 0) AS sold_qty,
            COALESCE(rev.avg_rating, 0) AS avg_rating,
            COALESCE(crt.cart_qty, 0) AS cart_qty,
            COALESCE(p.stock, 0) AS stock_qty,
            CASE
                WHEN COALESCE(p.discount_percent, 0) > 0 THEN COALESCE(p.discount_percent, 0)::numeric
                WHEN COALESCE(p.original_price, p.price) > p.price AND COALESCE(p.original_price, 0) > 0
                    THEN ((p.original_price - p.price)::numeric / p.original_price::numeric) * 100
                ELSE 0
            END AS effective_discount_pct,
            ROUND(
                (
                    (0.35 * LEAST(COALESCE(sales.sold_qty, 0)::numeric / v_max_sold, 1.0)) +
                    (0.25 * LEAST(COALESCE(rev.avg_rating, 0)::numeric / 5.0, 1.0)) +
                    (0.20 * LEAST(COALESCE(crt.cart_qty, 0)::numeric / v_max_cart, 1.0)) +
                    (0.10 * LEAST(
                        (CASE
                            WHEN COALESCE(p.discount_percent, 0) > 0 THEN COALESCE(p.discount_percent, 0)::numeric
                            WHEN COALESCE(p.original_price, p.price) > p.price AND COALESCE(p.original_price, 0) > 0
                                THEN ((p.original_price - p.price)::numeric / p.original_price::numeric) * 100
                            ELSE 0
                        END) / 50.0, 1.0)) +
                    (0.10 * LEAST(COALESCE(p.stock, 0)::numeric / v_max_stock, 1.0))
                ) * 100,
                1
            ) AS computed_score
        FROM public.products p
        LEFT JOIN (
            SELECT oi.product_id, SUM(oi.quantity)::int AS sold_qty
            FROM public.order_items oi
            JOIN public.orders o ON o.id = oi.order_id
            WHERE o.store_id = p_store_id
              AND o.payment_status = 'paid'
              AND o.status NOT IN ('cancelled', 'failed')
            GROUP BY oi.product_id
        ) sales ON sales.product_id = p.id
        LEFT JOIN (
            SELECT r.product_id, ROUND(AVG(r.rating)::numeric, 2) AS avg_rating
            FROM public.product_reviews r
            JOIN public.products rp ON rp.id = r.product_id
            WHERE rp.store_id = p_store_id AND r.is_approved = true
            GROUP BY r.product_id
        ) rev ON rev.product_id = p.id
        LEFT JOIN (
            SELECT ci.product_id, SUM(ci.quantity)::int AS cart_qty
            FROM public.cart_items ci
            JOIN public.products prod ON prod.id = ci.product_id
            WHERE prod.store_id = p_store_id
            GROUP BY ci.product_id
        ) crt ON crt.product_id = p.id
        WHERE p.store_id = p_store_id
          AND p.archived_at IS NULL
        ORDER BY computed_score DESC, COALESCE(sales.sold_qty, 0) DESC, p.created_at DESC
        LIMIT GREATEST(p_top_n, 1)
    ) LOOP
        v_rank := v_rank + 1;
        v_applied_count := v_applied_count + 1;

        INSERT INTO public.product_recommendations (
            product_id,
            priority,
            badge_text,
            is_active,
            formula_score,
            formula_mode,
            formula_breakdown,
            updated_at
        ) VALUES (
            v_rec.product_id,
            (100 - v_rank),
            CASE
                WHEN v_rank = 1 THEN 'Terlaris #1'
                ELSE 'Pilihan Terbaik'
            END,
            true,
            v_rec.computed_score,
            'formula',
            jsonb_build_object(
                'sold_qty', v_rec.sold_qty,
                'avg_rating', v_rec.avg_rating,
                'cart_qty', v_rec.cart_qty,
                'discount_pct', ROUND(v_rec.effective_discount_pct, 1),
                'stock', v_rec.stock_qty
            ),
            NOW()
        )
        ON CONFLICT (product_id) DO UPDATE SET
            priority = EXCLUDED.priority,
            badge_text = EXCLUDED.badge_text,
            is_active = true,
            formula_score = EXCLUDED.formula_score,
            formula_mode = 'formula',
            formula_breakdown = EXCLUDED.formula_breakdown,
            updated_at = NOW();
    END LOOP;

    RETURN jsonb_build_object(
        'applied_count', v_applied_count,
        'top_n', p_top_n
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_store_product_recommendation_metrics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.apply_auto_store_recommendations(UUID, INT) TO authenticated;

NOTIFY pgrst, 'reload schema';
