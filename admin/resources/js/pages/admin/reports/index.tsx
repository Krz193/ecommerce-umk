import { Head } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency } from '@/lib/format';

type ReportsIndexProps = {
    financeSummary: {
        paid_revenue: string;
        application_fee: string;
        paid_orders: number;
        pending_payments: number;
    };
    storeSummary: {
        total: number;
        active: number;
        pending: number;
        suspended: number;
    };
    storeReports: Array<{
        id: string;
        name: string;
        status: string;
        product_count: number;
        published_product_count: number;
        order_count: number;
        buyer_count: number;
        paid_revenue: string;
    }>;
    stockReports: Array<{
        id: string;
        name: string;
        status: string;
        stock: number;
        price: string;
        store_name: string;
        category_name: string | null;
    }>;
};

export default function ReportsIndex({ financeSummary, storeSummary, storeReports, stockReports }: ReportsIndexProps) {
    return (
        <>
            <Head title="Reports" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Reports</h1>
                    <p className="text-sm text-muted-foreground">MVP reports for UMK, stock, and finance monitoring.</p>
                </div>

                <div className="grid gap-3 md:grid-cols-4">
                    <Metric title="Total UMK" value={String(storeSummary.total)} />
                    <Metric title="Active UMK" value={String(storeSummary.active)} />
                    <Metric title="Pending UMK" value={String(storeSummary.pending)} />
                    <Metric title="Suspended UMK" value={String(storeSummary.suspended)} />
                </div>

                <div className="grid gap-3 md:grid-cols-4">
                    <Metric title="Paid Revenue" value={formatCurrency(financeSummary.paid_revenue)} />
                    <Metric title="Application Fee" value={formatCurrency(financeSummary.application_fee)} />
                    <Metric title="Paid Orders" value={String(financeSummary.paid_orders)} />
                    <Metric title="Pending Payments" value={String(financeSummary.pending_payments)} />
                </div>

                <Card>
                    <CardHeader><CardTitle>UMK Financial Summary</CardTitle></CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[920px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Store</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Products</th>
                                    <th className="pb-3 font-medium">Published</th>
                                    <th className="pb-3 font-medium">Orders</th>
                                    <th className="pb-3 font-medium">Buyers</th>
                                    <th className="pb-3 text-right font-medium">Paid Revenue</th>
                                </tr>
                            </thead>
                            <tbody>
                                {storeReports.map((store) => (
                                    <tr key={store.id} className="border-b last:border-0">
                                        <td className="py-3 font-medium">{store.name}</td>
                                        <td className="py-3"><StatusBadge status={store.status} /></td>
                                        <td className="py-3">{store.product_count}</td>
                                        <td className="py-3">{store.published_product_count}</td>
                                        <td className="py-3">{store.order_count}</td>
                                        <td className="py-3">{store.buyer_count}</td>
                                        <td className="py-3 text-right">{formatCurrency(store.paid_revenue)}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader><CardTitle>Low Stock Report</CardTitle></CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[760px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Product</th>
                                    <th className="pb-3 font-medium">Store</th>
                                    <th className="pb-3 font-medium">Category</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Stock</th>
                                    <th className="pb-3 text-right font-medium">Price</th>
                                </tr>
                            </thead>
                            <tbody>
                                {stockReports.map((product) => (
                                    <tr key={product.id} className="border-b last:border-0">
                                        <td className="py-3 font-medium">{product.name}</td>
                                        <td className="py-3">{product.store_name}</td>
                                        <td className="py-3">{product.category_name || '-'}</td>
                                        <td className="py-3"><StatusBadge status={product.status} /></td>
                                        <td className="py-3">{product.stock}</td>
                                        <td className="py-3 text-right">{formatCurrency(product.price)}</td>
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

function Metric({ title, value }: { title: string; value: string }) {
    return (
        <Card className="gap-2 py-4">
            <CardHeader className="px-4">
                <CardTitle className="text-sm text-muted-foreground">{title}</CardTitle>
            </CardHeader>
            <CardContent className="px-4 text-2xl font-semibold">{value}</CardContent>
        </Card>
    );
}

ReportsIndex.layout = {
    breadcrumbs: [
        {
            title: 'Reports',
            href: '/reports',
        },
    ],
};
