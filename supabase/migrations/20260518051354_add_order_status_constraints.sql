alter table public.orders
add constraint orders_status_check
check (
    status in (
        'pending',
        'processing',
        'shipped',
        'completed',
        'cancelled'
    )
);

alter table public.orders
add constraint orders_payment_status_check
check (
    payment_status in (
        'pending',
        'paid',
        'failed',
        'refunded',
        'expired'
    )
);