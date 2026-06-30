import { Head, Link } from '@inertiajs/react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { formatCurrency, formatDate } from '@/lib/format';

type DashboardProps = {
    metrics: Record<string, number>;
    recentStores: Array<{
        id: string;
        name: string;
        status: string;
        phone: string | null;
        created_at: string;
    }>;
    recentOrders: Array<{
        id: string;
        order_number: string;
        status: string;
        payment_status: string;
        total_amount: string;
        created_at: string;
        store_name: string;
    }>;
};

const metricLabels: Record<string, string> = {
    stores_pending: 'Pending Stores',
    stores_active: 'Active Stores',
    products_published: 'Published Products',
    orders_processing: 'Processing Orders',
    payments_pending: 'Pending Payments',
    payments_paid: 'Paid Payments',
};

export default function Dashboard({ metrics, recentStores, recentOrders }: DashboardProps) {
    return (
        <>
            <Head title="Dashboard" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Admin Dashboard</h1>
                    <p className="text-sm text-muted-foreground">Operational overview for moderation and order support.</p>
                </div>
                <div className="grid gap-3 md:grid-cols-3 xl:grid-cols-6">
                    {Object.entries(metricLabels).map(([key, label]) => (
                        <Card key={key} className="gap-2 py-4">
                            <CardHeader className="px-4">
                                <CardTitle className="text-sm text-muted-foreground">{label}</CardTitle>
                            </CardHeader>
                            <CardContent className="px-4 text-2xl font-semibold">{metrics[key] ?? 0}</CardContent>
                        </Card>
                    ))}
                </div>
                <div className="grid gap-4 xl:grid-cols-2">
                    <Card>
                        <CardHeader className="flex-row items-center justify-between">
                            <CardTitle>Recent Stores</CardTitle>
                            <Button asChild variant="outline" size="sm">
                                <Link href="/stores">View stores</Link>
                            </Button>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {recentStores.map((store) => (
                                <div key={store.id} className="flex items-center justify-between gap-3 border-b pb-3 last:border-0 last:pb-0">
                                    <div>
                                        <Link href={`/stores/${store.id}`} className="font-medium hover:underline">
                                            {store.name}
                                        </Link>
                                        <div className="text-xs text-muted-foreground">{store.phone || '-'} · {formatDate(store.created_at)}</div>
                                    </div>
                                    <StatusBadge status={store.status} />
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="flex-row items-center justify-between">
                            <CardTitle>Recent Orders</CardTitle>
                            <Button asChild variant="outline" size="sm">
                                <Link href="/orders">View orders</Link>
                            </Button>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {recentOrders.map((order) => (
                                <div key={order.id} className="flex items-center justify-between gap-3 border-b pb-3 last:border-0 last:pb-0">
                                    <div>
                                        <Link href={`/orders/${order.id}`} className="font-medium hover:underline">
                                            {order.order_number}
                                        </Link>
                                        <div className="text-xs text-muted-foreground">{order.store_name} · {formatCurrency(order.total_amount)}</div>
                                    </div>
                                    <div className="flex gap-2">
                                        <StatusBadge status={order.payment_status} />
                                        <StatusBadge status={order.status} />
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                </div>
            </div>
        </>
    );
}

Dashboard.layout = {
    breadcrumbs: [
        {
            title: 'Dashboard',
            href: '/dashboard',
        },
    ],
};
