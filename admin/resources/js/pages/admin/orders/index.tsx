import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { formatCurrency, formatDate } from '@/lib/format';
import type { OrderRow, Paginated } from '@/types';

type OrdersIndexProps = {
    orders: Paginated<OrderRow>;
    filters: {
        status: string;
        payment_status: string;
        search: string;
    };
};

export default function OrdersIndex({ orders, filters }: OrdersIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');
    const [paymentStatus, setPaymentStatus] = useState(filters.payment_status || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/orders', { search, status, payment_status: paymentStatus }, { preserveState: true, replace: true });
    }

    return (
        <>
            <Head title="Orders" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Order Lookup</h1>
                    <p className="text-sm text-muted-foreground">Read-only order and payment inspection for operational support.</p>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="grid gap-3 md:grid-cols-[1fr_180px_180px_auto]">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search order, buyer, or store" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="">All orders</option>
                                <option value="pending">Pending</option>
                                <option value="processing">Processing</option>
                                <option value="shipped">Shipped</option>
                                <option value="completed">Completed</option>
                                <option value="cancelled">Cancelled</option>
                            </select>
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={paymentStatus} onChange={(event) => setPaymentStatus(event.target.value)}>
                                <option value="">All payments</option>
                                <option value="pending">Pending</option>
                                <option value="paid">Paid</option>
                                <option value="failed">Failed</option>
                                <option value="expired">Expired</option>
                            </select>
                            <Button type="submit">
                                <Search />
                                Filter
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardContent className="overflow-x-auto pt-6">
                        <table className="w-full min-w-[980px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Order</th>
                                    <th className="pb-3 font-medium">Store</th>
                                    <th className="pb-3 font-medium">Customer</th>
                                    <th className="pb-3 font-medium">Total</th>
                                    <th className="pb-3 font-medium">Payment</th>
                                    <th className="pb-3 font-medium">Order Status</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {orders.data.map((order) => (
                                    <tr key={order.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/orders/${order.id}`} className="font-medium hover:underline">
                                                {order.order_number}
                                            </Link>
                                            <div className="text-xs text-muted-foreground">{order.provider_transaction_id || '-'}</div>
                                        </td>
                                        <td className="py-3">{order.store_name}</td>
                                        <td className="py-3">{order.shipping_name}</td>
                                        <td className="py-3">{formatCurrency(order.total_amount)}</td>
                                        <td className="py-3"><StatusBadge status={order.payment_status} /></td>
                                        <td className="py-3"><StatusBadge status={order.status} /></td>
                                        <td className="py-3">{formatDate(order.created_at)}</td>
                                        <td className="py-3 text-right">
                                            <Button asChild variant="outline" size="sm">
                                                <Link href={`/orders/${order.id}`}>Detail</Link>
                                            </Button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {orders.data.length === 0 && (
                            <div className="py-10 text-center text-sm text-muted-foreground">No orders found.</div>
                        )}
                    </CardContent>
                </Card>

                <Pagination links={orders.links} />
            </div>
        </>
    );
}

OrdersIndex.layout = {
    breadcrumbs: [
        {
            title: 'Orders',
            href: '/orders',
        },
    ],
};
