import { Head, Link, router } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency } from '@/lib/format';
import type { ProductRow, StoreRow } from '@/types';

type StoreShowProps = {
    store: StoreRow & {
        description: string | null;
        owner_username: string | null;
        payout_provider: string | null;
        payout_account_name: string | null;
        payout_account_number: string | null;
    };
    metrics: Record<string, number>;
    recentProducts: ProductRow[];
};

export default function StoreShow({ store, metrics, recentProducts }: StoreShowProps) {
    function approve() {
        const action = store.status === 'suspended' ? 'Unsuspend' : 'Approve';

        if (confirm(`${action} ${store.name}?`)) {
            router.patch(`/stores/${store.id}/approve`);
        }
    }

    function suspend() {
        if (confirm(`Suspend ${store.name}?`)) {
            router.patch(`/stores/${store.id}/suspend`);
        }
    }

    return (
        <>
            <Head title={store.name} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <div className="mb-2"><StatusBadge status={store.status} /></div>
                        <h1 className="text-2xl font-semibold">{store.name}</h1>
                        <p className="text-sm text-muted-foreground">{store.slug}</p>
                    </div>
                    <div className="flex gap-2">
                        {store.status !== 'active' && (
                            <Button onClick={approve}>
                                {store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                            </Button>
                        )}
                        {store.status !== 'suspended' && <Button variant="destructive" onClick={suspend}>Suspend</Button>}
                    </div>
                </div>

                <div className="grid gap-3 md:grid-cols-4">
                    {Object.entries(metrics).map(([key, value]) => (
                        <Card key={key} className="gap-2 py-4">
                            <CardHeader className="px-4">
                                <CardTitle className="text-sm capitalize text-muted-foreground">{key.replaceAll('_', ' ')}</CardTitle>
                            </CardHeader>
                            <CardContent className="px-4 text-2xl font-semibold">{value}</CardContent>
                        </Card>
                    ))}
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                    <Card>
                        <CardHeader><CardTitle>Store Information</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Owner" value={store.owner_name || '-'} />
                            <Info label="Owner Phone" value={store.owner_phone || '-'} />
                            <Info label="Store Phone" value={store.phone || '-'} />
                            <Info label="Address" value={store.address || '-'} />
                            <Info label="Description" value={store.description || '-'} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Payout Information</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Provider" value={store.payout_provider || '-'} />
                            <Info label="Account Name" value={store.payout_account_name || '-'} />
                            <Info label="Account Number" value={store.payout_account_number || '-'} />
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader><CardTitle>Recent Products</CardTitle></CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[760px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Product</th>
                                    <th className="pb-3 font-medium">Category</th>
                                    <th className="pb-3 font-medium">Price</th>
                                    <th className="pb-3 font-medium">Stock</th>
                                    <th className="pb-3 font-medium">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentProducts.map((product) => (
                                    <tr key={product.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/products/${product.id}`} className="font-medium hover:underline">
                                                {product.name}
                                            </Link>
                                        </td>
                                        <td className="py-3">{product.category_name || '-'}</td>
                                        <td className="py-3">{formatCurrency(product.price)}</td>
                                        <td className="py-3">{product.stock}</td>
                                        <td className="py-3"><StatusBadge status={product.status} /></td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>
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

StoreShow.layout = {
    breadcrumbs: [
        {
            title: 'Stores',
            href: '/stores',
        },
    ],
};
