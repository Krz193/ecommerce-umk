export type PageLink = {
    url: string | null;
    label: string;
    active: boolean;
};

export type Paginated<T> = {
    data: T[];
    links: PageLink[];
    current_page: number;
    last_page: number;
    from: number | null;
    to: number | null;
    total: number;
};

export type StoreRow = {
    id: string;
    name: string;
    slug: string;
    status: string;
    phone: string | null;
    address: string | null;
    created_at: string;
    suspended_at: string | null;
    owner_name: string | null;
    owner_phone: string | null;
};

export type CategoryRow = {
    id: string;
    name: string;
    slug: string;
    icon_url: string | null;
    is_active: boolean;
    created_at: string;
    products_count: number;
};

export type StoreContentRow = {
    id: string;
    store_id: string;
    product_id: string | null;
    title: string;
    content_type: 'banner' | 'promo' | 'storytelling' | 'social' | 'educational';
    social_platform: string | null;
    media_format: 'image' | 'video' | 'short_video' | 'carousel' | 'article';
    external_url: string | null;
    body: string | null;
    is_active: boolean;
    reach_count: number;
    likes_count: number;
    comments_count: number;
    shares_count: number;
    inquiries_count: number;
    created_at: string;
    store_name: string;
    product_name: string | null;
    creator_name: string | null;
};



export type ProductRow = {
    id: string;
    name: string;
    status: string;
    price: string;
    original_price: string | null;
    discount_percent: string;
    discount_amount: string;
    tax_percent: string;
    stock: number;
    thumbnail_url: string | null;
    archived_at: string | null;
    created_at: string;
    store_name: string;
    category_name: string | null;
};

export type OrderRow = {
    id: string;
    order_number: string;
    status: string;
    payment_status: string;
    total_amount: string;
    shipping_name: string;
    created_at: string;
    store_name: string;
    provider: string | null;
    provider_transaction_id: string | null;
};

export type MarketplaceUserRow = {
    id: string;
    full_name: string;
    email: string | null;
    username: string | null;
    phone: string | null;
    role: string;
    last_sign_in_at: string | null;
    created_at: string;
};

export type AuditLogRow = {
    id: number;
    action: string;
    target_type: string;
    target_id: string;
    reason: string;
    metadata: Record<string, unknown> | null;
    created_at: string;
    admin_name: string;
    admin_email: string;
};

export type RefundCaseRow = {
    id: string;
    case_key: string;
    source: 'local' | 'marketplace';
    order_id: string;
    status: string;
    request_type: string;
    requester_role: string;
    reason: string;
    admin_notes: string | null;
    created_by_name: string;
    resolved_by_name: string | null;
    resolved_at: string | null;
    created_at: string;
};

export type SystemFeedbackRow = {
    id: string;
    user_id: string;
    user_role: string;
    category: 'saran' | 'masukan' | 'kendala_sistem' | 'bantuan_operasional' | 'lainnya';
    subject: string;
    message: string;
    status: 'pending' | 'in_review' | 'resolved' | 'rejected';
    admin_notes: string | null;
    created_at: string;
    updated_at: string;
    user_name: string | null;
    user_phone: string | null;
    user_username: string | null;
};

export type SaleEventRow = {
    id: string;
    store_id: string | null;
    title: string;
    slug: string;
    description: string | null;
    banner_url: string | null;
    start_time: string;
    end_time: string;
    is_active: boolean;
    created_at: string;
    store_name: string | null;
    total_items?: number;
    total_sold?: number;
};

export type SaleEventItemRow = {
    id: string;
    sale_event_id: string;
    product_id: string;
    store_id: string;
    discount_type: 'percentage' | 'nominal' | 'fixed_price';
    discount_value: string | number;
    sale_price: string | number;
    sale_quota: number | null;
    sold_count: number;
    max_qty_per_user: number | null;
    is_active: boolean;
    created_at: string;
    product_name: string;
    regular_price: string | number;
    product_stock: number;
    product_thumbnail: string | null;
    product_status: string;
    store_name: string;
};

export type NotificationRow = {
    id: string;
    user_id: string;
    category: 'transaction' | 'promo' | 'system';
    type: string;
    title: string;
    body: string;
    target_route: string | null;
    is_read: boolean;
    read_at: string | null;
    created_at: string;
    user_name: string | null;
    user_role: string | null;
    user_email: string | null;
};
