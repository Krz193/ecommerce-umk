-- Migration: Batch 1B — UMK & Assistant UMK Updates (#3, #6, #15, #16, #17)

-- 1. #3 Product Recommendations: Formula Columns, Grants & RLS for UMK Store Owner + Assistant, and Metrics RPC
ALTER TABLE public.product_recommendations
    ADD COLUMN IF NOT EXISTS formula_score NUMERIC(8,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS formula_mode VARCHAR(32) NOT NULL DEFAULT 'manual',
    ADD COLUMN IF NOT EXISTS formula_breakdown JSONB NOT NULL DEFAULT '{}'::jsonb;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.product_recommendations TO authenticated;

DROP POLICY IF EXISTS "Store owners and assistants can view own store recommendations" ON public.product_recommendations;
CREATE POLICY "Store owners and assistants can view own store recommendations"
ON public.product_recommendations FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.stores s ON s.id = p.store_id
        WHERE p.id = product_recommendations.product_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
);

DROP POLICY IF EXISTS "Store owners and assistants can manage own store recommendations" ON public.product_recommendations;
CREATE POLICY "Store owners and assistants can manage own store recommendations"
ON public.product_recommendations FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.stores s ON s.id = p.store_id
        WHERE p.id = product_recommendations.product_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.stores s ON s.id = p.store_id
        WHERE p.id = product_recommendations.product_id
          AND (
              s.owner_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.store_assistants sa
                  WHERE sa.store_id = s.id AND sa.user_id = auth.uid()
              )
          )
    )
);

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
        SELECT product_id, round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS review_count
        FROM public.product_reviews
        WHERE store_id = p_store_id AND is_approved = true
        GROUP BY product_id
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

GRANT EXECUTE ON FUNCTION public.get_store_product_recommendation_metrics(uuid) TO authenticated;

-- 2. #6 Update get_seller_cart_insights to include buyer_carts breakdown
CREATE OR REPLACE FUNCTION public.get_seller_cart_insights(p_store_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_items integer := 0;
    v_total_potential_value numeric := 0;
    v_unique_potential_buyers integer := 0;
    v_product_breakdown json := '[]'::json;
    v_buyer_carts json := '[]'::json;
    v_result json;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.stores
        WHERE id = p_store_id
          AND (owner_id = auth.uid() OR EXISTS (
              SELECT 1 FROM public.store_assistants
              WHERE store_id = p_store_id AND user_id = auth.uid()
          ))
    ) THEN
        RAISE EXCEPTION 'Unauthorized to view cart insights for this store';
    END IF;

    SELECT
        coalesce(sum(ci.quantity), 0),
        coalesce(sum(ci.quantity * p.price), 0),
        count(DISTINCT c.user_id)
    INTO
        v_total_items,
        v_total_potential_value,
        v_unique_potential_buyers
    FROM public.cart_items ci
    JOIN public.carts c ON ci.cart_id = c.id
    JOIN public.products p ON ci.product_id = p.id
    WHERE p.store_id = p_store_id;

    SELECT coalesce(json_agg(
        json_build_object(
            'product_id', sub.product_id,
            'product_name', sub.name,
            'product_image', sub.image_url,
            'price', sub.price,
            'stock', sub.stock,
            'total_quantity', sub.total_qty,
            'total_potential_value', sub.total_value,
            'unique_buyers', sub.buyer_count
        ) ORDER BY sub.total_qty DESC
    ), '[]'::json)
    INTO v_product_breakdown
    FROM (
        SELECT
            p.id AS product_id,
            p.name,
            coalesce(p.thumbnail_url, (
                SELECT pi.image_url
                FROM public.product_images pi
                WHERE pi.product_id = p.id
                ORDER BY pi.sort_order ASC
                LIMIT 1
            )) AS image_url,
            p.price,
            p.stock,
            sum(ci.quantity) AS total_qty,
            sum(ci.quantity * p.price) AS total_value,
            count(DISTINCT c.user_id) AS buyer_count
        FROM public.cart_items ci
        JOIN public.carts c ON ci.cart_id = c.id
        JOIN public.products p ON ci.product_id = p.id
        WHERE p.store_id = p_store_id
        GROUP BY p.id, p.name, p.thumbnail_url, p.price, p.stock
    ) sub;

    SELECT coalesce(json_agg(
        json_build_object(
            'user_id', b_sub.user_id,
            'buyer_name', b_sub.buyer_name,
            'buyer_phone', b_sub.buyer_phone,
            'total_items', b_sub.total_items,
            'total_value', b_sub.total_value,
            'updated_at', b_sub.updated_at,
            'items', b_sub.items
        ) ORDER BY b_sub.total_value DESC
    ), '[]'::json)
    INTO v_buyer_carts
    FROM (
        SELECT
            c.user_id,
            coalesce(u.full_name, 'Pembeli Terdaftar') AS buyer_name,
            u.phone AS buyer_phone,
            sum(ci.quantity)::int AS total_items,
            sum(ci.quantity * p.price)::bigint AS total_value,
            max(ci.created_at) AS updated_at,
            json_agg(
                json_build_object(
                    'product_id', p.id,
                    'product_name', p.name,
                    'price', p.price,
                    'quantity', ci.quantity,
                    'subtotal', (ci.quantity * p.price)
                )
            ) AS items
        FROM public.cart_items ci
        JOIN public.carts c ON ci.cart_id = c.id
        JOIN public.products p ON ci.product_id = p.id
        LEFT JOIN public.users u ON u.id = c.user_id
        WHERE p.store_id = p_store_id
        GROUP BY c.user_id, u.full_name, u.phone
    ) b_sub;

    v_result := json_build_object(
        'total_items_in_carts', v_total_items,
        'total_potential_value', v_total_potential_value,
        'unique_potential_buyers', v_unique_potential_buyers,
        'product_breakdown', v_product_breakdown,
        'buyer_carts', v_buyer_carts
    );

    RETURN v_result;
END;
$$;

-- 3. #16 Asisten UMK: CRUD Engagement on assistance_logs
ALTER TABLE public.assistance_logs DROP CONSTRAINT IF EXISTS assistance_logs_action_type_check;
ALTER TABLE public.assistance_logs ADD CONSTRAINT assistance_logs_action_type_check CHECK (
    action_type IN (
        'create_product',
        'update_product',
        'update_stock',
        'ship_order',
        'create_content',
        'update_content',
        'update_profile',
        'engagement',
        'other'
    )
);

ALTER TABLE public.assistance_logs
    ADD COLUMN IF NOT EXISTS channel VARCHAR(50) NULL,
    ADD COLUMN IF NOT EXISTS reach_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS shares_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS inquiries_count INTEGER NOT NULL DEFAULT 0;

GRANT UPDATE, DELETE ON public.assistance_logs TO authenticated;

DROP POLICY IF EXISTS "Assistants and store owners can update assistance logs" ON public.assistance_logs;
CREATE POLICY "Assistants and store owners can update assistance logs"
ON public.assistance_logs FOR UPDATE TO authenticated
USING (
    auth.uid() = assistant_id
    OR EXISTS (
        SELECT 1 FROM public.store_assistants sa
        WHERE sa.store_id = assistance_logs.store_id AND sa.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = assistance_logs.store_id AND s.owner_id = auth.uid()
    )
)
WITH CHECK (
    auth.uid() = assistant_id
    OR EXISTS (
        SELECT 1 FROM public.store_assistants sa
        WHERE sa.store_id = assistance_logs.store_id AND sa.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = assistance_logs.store_id AND s.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Assistants and store owners can delete assistance logs" ON public.assistance_logs;
CREATE POLICY "Assistants and store owners can delete assistance logs"
ON public.assistance_logs FOR DELETE TO authenticated
USING (
    auth.uid() = assistant_id
    OR EXISTS (
        SELECT 1 FROM public.store_assistants sa
        WHERE sa.store_id = assistance_logs.store_id AND sa.user_id = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.stores s
        WHERE s.id = assistance_logs.store_id AND s.owner_id = auth.uid()
    )
);

-- 4. #17 Metadata Konten UMK: social_platform, media_format, external_url
ALTER TABLE public.store_contents
    ADD COLUMN IF NOT EXISTS social_platform VARCHAR(50) NULL,
    ADD COLUMN IF NOT EXISTS media_format VARCHAR(50) NOT NULL DEFAULT 'image',
    ADD COLUMN IF NOT EXISTS external_url TEXT NULL;

NOTIFY pgrst, 'reload schema';
