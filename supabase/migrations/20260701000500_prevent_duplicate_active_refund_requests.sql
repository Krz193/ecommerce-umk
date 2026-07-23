create unique index if not exists idx_refunds_one_active_request_per_role
on public.refunds(order_id, requester_role)
where status in ('requested', 'open', 'reviewing');
