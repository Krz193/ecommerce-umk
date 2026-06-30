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
