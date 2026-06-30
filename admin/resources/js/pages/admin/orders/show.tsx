import { Head, Link } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';

type OrderDetail = {
    id: string;
    order_number: string;
    status: string;
    payment_status: string;
    subtotal: string;
    shipping_cost: string;
    application_fee: string;
    total_amount: string;
    shipping_name: string;
    shipping_phone: string;
    shipping_address: string;
    shipping_city: string;
    shipping_postal_code: string | null;
    shipping_provider: string | null;
    tracking_number: string | null;
    placed_at: string | null;
    paid_at: string | null;
    completed_at: string | null;
    cancelled_at: string | null;
    created_at: string;
    store_name: string;
    buyer_name: string | null;
    buyer_phone: string | null;
    provider: string | null;
    provider_transaction_id: string | null;
    provider_status: string | null;
    payment_amount: string | null;
    payment_paid_at: string | null;
    payment_expired_at: string | null;
};

type OrderItem = {
    product_name: string;
    product_price: string;
    quantity: number;
    subtotal: string;
    product_thumbnail: string | null;
};

type OrderShowProps = {
    order: OrderDetail;
    items: OrderItem[];
};

export default function OrderShow({ order, items }: OrderShowProps) {
    return (
        <>
            <Head title={order.order_number} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <div className="mb-2 flex gap-2">
                            <StatusBadge status={order.payment_status} />
                            <StatusBadge status={order.status} />
                        </div>
                        <h1 className="text-2xl font-semibold">{order.order_number}</h1>
                        <p className="text-sm text-muted-foreground">{order.store_name} · {formatDate(order.created_at)}</p>
                    </div>
                    <Button asChild variant="outline">
                        <Link href="/orders">Back to orders</Link>
                    </Button>
                </div>

                <div className="grid gap-4 xl:grid-cols-3">
                    <Card>
                        <CardHeader><CardTitle>Customer</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Buyer" value={order.buyer_name || '-'} />
                            <Info label="Buyer Phone" value={order.buyer_phone || '-'} />
                            <Info label="Shipping Name" value={order.shipping_name} />
                            <Info label="Shipping Phone" value={order.shipping_phone} />
                            <Info label="Address" value={`${order.shipping_address}, ${order.shipping_city} ${order.shipping_postal_code || ''}`} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Payment</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Provider" value={order.provider || '-'} />
                            <Info label="Provider Transaction" value={order.provider_transaction_id || '-'} />
                            <Info label="Provider Status" value={order.provider_status || '-'} />
                            <Info label="Payment Amount" value={formatCurrency(order.payment_amount)} />
                            <Info label="Paid At" value={formatDate(order.payment_paid_at)} />
                            <Info label="Expired At" value={formatDate(order.payment_expired_at)} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Shipment</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Provider" value={order.shipping_provider || '-'} />
                            <Info label="Tracking Number" value={order.tracking_number || '-'} />
                            <Info label="Placed At" value={formatDate(order.placed_at)} />
                            <Info label="Order Paid At" value={formatDate(order.paid_at)} />
                            <Info label="Completed At" value={formatDate(order.completed_at)} />
                            <Info label="Cancelled At" value={formatDate(order.cancelled_at)} />
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader><CardTitle>Items</CardTitle></CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[720px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Product</th>
                                    <th className="pb-3 font-medium">Price</th>
                                    <th className="pb-3 font-medium">Qty</th>
                                    <th className="pb-3 text-right font-medium">Subtotal</th>
                                </tr>
                            </thead>
                            <tbody>
                                {items.map((item) => (
                                    <tr key={`${item.product_name}-${item.quantity}`} className="border-b last:border-0">
                                        <td className="py-3">
                                            <div className="flex items-center gap-3">
                                                {item.product_thumbnail && <img src={item.product_thumbnail} alt={item.product_name} className="size-10 rounded object-cover" />}
                                                <span>{item.product_name}</span>
                                            </div>
                                        </td>
                                        <td className="py-3">{formatCurrency(item.product_price)}</td>
                                        <td className="py-3">{item.quantity}</td>
                                        <td className="py-3 text-right">{formatCurrency(item.subtotal)}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader><CardTitle>Totals</CardTitle></CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <Total label="Subtotal" value={order.subtotal} />
                        <Total label="Shipping" value={order.shipping_cost} />
                        <Total label="Application Fee" value={order.application_fee} />
                        <div className="border-t pt-2">
                            <Total label="Total" value={order.total_amount} strong />
                        </div>
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

function Total({ label, value, strong = false }: { label: string; value: string; strong?: boolean }) {
    return (
        <div className={`flex justify-between ${strong ? 'text-base font-semibold' : ''}`}>
            <span>{label}</span>
            <span>{formatCurrency(value)}</span>
        </div>
    );
}

OrderShow.layout = {
    breadcrumbs: [
        {
            title: 'Orders',
            href: '/orders',
        },
    ],
};
