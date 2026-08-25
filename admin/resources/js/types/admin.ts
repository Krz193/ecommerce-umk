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
    body: string | null;
    is_active: boolean;
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
    username: string | null;
    phone: string | null;
    role: string;
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
