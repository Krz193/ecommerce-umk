alter table public.payments
add constraint payments_status_check
check (
    status in (
        'pending',
        'paid',
        'failed',
        'expired',
        'refunded',
        'partially_refunded'
    )
);