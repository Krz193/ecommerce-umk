import { Head, Link } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';

type UserShowProps = {
    user: {
        id: string;
        full_name: string;
        username: string | null;
        phone: string | null;
        avatar_url: string | null;
        role: string;
        created_at: string;
        updated_at: string;
    };
    stores: Array<{
        id: string;
        name: string;
        slug: string;
        status: string;
        created_at: string;
    }>;
    orders: Array<{
        id: string;
        order_number: string;
        status: string;
        payment_status: string;
        total_amount: string;
        created_at: string;
        store_name: string;
    }>;
};

export default function UserShow({ user, stores, orders }: UserShowProps) {
    return (
        <>
            <Head title={user.full_name} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <div className="mb-2"><StatusBadge status={user.role} /></div>
                    <h1 className="text-2xl font-semibold">{user.full_name}</h1>
                    <p className="text-sm text-muted-foreground">{user.username || user.id}</p>
                </div>

                <Card>
                    <CardHeader><CardTitle>User Information</CardTitle></CardHeader>
                    <CardContent className="grid gap-3 text-sm md:grid-cols-2">
                        <Info label="Phone" value={user.phone || '-'} />
                        <Info label="Created" value={formatDate(user.created_at)} />
                        <Info label="Updated" value={formatDate(user.updated_at)} />
                        <Info label="User ID" value={user.id} />
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader><CardTitle>Stores</CardTitle></CardHeader>
                    <CardContent className="space-y-3">
                        {stores.map((store) => (
                            <div key={store.id} className="flex items-center justify-between border-b pb-3 last:border-0 last:pb-0">
                                <div>
                                    <Link href={`/stores/${store.id}`} className="font-medium hover:underline">{store.name}</Link>
                                    <div className="text-xs text-muted-foreground">{store.slug}</div>
                                </div>
                                <StatusBadge status={store.status} />
                            </div>
                        ))}
                        {stores.length === 0 && <div className="text-sm text-muted-foreground">No store found.</div>}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader><CardTitle>Recent Orders</CardTitle></CardHeader>
                    <CardContent className="space-y-3">
                        {orders.map((order) => (
                            <div key={order.id} className="flex items-center justify-between border-b pb-3 last:border-0 last:pb-0">
                                <div>
                                    <Link href={`/orders/${order.id}`} className="font-medium hover:underline">{order.order_number}</Link>
                                    <div className="text-xs text-muted-foreground">{order.store_name} · {formatCurrency(order.total_amount)}</div>
                                </div>
                                <div className="flex gap-2">
                                    <StatusBadge status={order.payment_status} />
                                    <StatusBadge status={order.status} />
                                </div>
                            </div>
                        ))}
                        {orders.length === 0 && <div className="text-sm text-muted-foreground">No order found.</div>}
                    </CardContent>
                </Card>

                <Button asChild variant="outline" className="w-fit">
                    <Link href="/users">Back to users</Link>
                </Button>
            </div>
        </>
    );
}

function Info({ label, value }: { label: string; value: string }) {
    return (
        <div>
            <div className="text-xs text-muted-foreground">{label}</div>
            <div>{value}</div>
        </div>
    );
}

UserShow.layout = {
    breadcrumbs: [
        {
            title: 'Users',
            href: '/users',
        },
    ],
};
