import { Head, Link } from '@inertiajs/react';
import { RefundCaseUpdateDialog } from '@/components/admin/refund-case-update-dialog';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';
import type { RefundCaseRow } from '@/types';

type RefundCaseShowProps = {
    refundCase: RefundCaseRow;
    order: {
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
        store_name: string;
        buyer_name: string | null;
        buyer_phone: string | null;
        provider: string | null;
        provider_transaction_id: string | null;
        provider_status: string | null;
        payment_amount: string | null;
        payment_paid_at: string | null;
        payment_expired_at: string | null;
        created_at: string;
    };
    items: Array<{
        product_name: string;
        product_price: string;
        quantity: number;
        subtotal: string;
        product_thumbnail: string | null;
    }>;
    logs: Array<{
        id: number;
        action: string;
        reason: string;
        created_at: string;
        admin_name: string;
    }>;
};

export default function RefundCaseShow({ refundCase, order, items, logs }: RefundCaseShowProps) {
    return (
        <>
            <Head title={`Refund Case #${refundCase.id}`} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <div className="mb-2"><StatusBadge status={refundCase.status} /></div>
                        <h1 className="text-2xl font-semibold">Refund Case #{refundCase.id}</h1>
                        <p className="text-sm text-muted-foreground">{order.order_number} · {order.store_name}</p>
                    </div>
                    <div className="flex gap-2">
                        <RefundCaseUpdateDialog refundCase={refundCase} />
                        <Button asChild variant="outline">
                            <Link href="/refund-cases">Back to cases</Link>
                        </Button>
                    </div>
                </div>

                <div className="grid gap-4 xl:grid-cols-3">
                    <Card>
                        <CardHeader><CardTitle>Case</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Reason" value={refundCase.reason} />
                            <Info label="Admin Notes" value={refundCase.admin_notes || '-'} />
                            <Info label="Created By" value={refundCase.created_by_name} />
                            <Info label="Resolved By" value={refundCase.resolved_by_name || '-'} />
                            <Info label="Resolved At" value={formatDate(refundCase.resolved_at)} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Order</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Order Number" value={order.order_number} />
                            <Info label="Customer" value={order.buyer_name || order.shipping_name} />
                            <Info label="Phone" value={order.buyer_phone || order.shipping_phone} />
                            <Info label="Order Status" value={order.status} />
                            <Info label="Payment Status" value={order.payment_status} />
                            <Info label="Total" value={formatCurrency(order.total_amount)} />
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
                                        <td className="py-3">{item.product_name}</td>
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
                    <CardHeader><CardTitle>Timeline</CardTitle></CardHeader>
                    <CardContent className="space-y-3">
                        {logs.map((log) => (
                            <div key={log.id} className="border-b pb-3 last:border-0 last:pb-0">
                                <div className="flex flex-col justify-between gap-1 md:flex-row">
                                    <div className="font-medium">{log.action}</div>
                                    <div className="text-sm text-muted-foreground">{formatDate(log.created_at)}</div>
                                </div>
                                <div className="text-sm text-muted-foreground">{log.admin_name}</div>
                                <div className="text-sm">{log.reason}</div>
                            </div>
                        ))}
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

RefundCaseShow.layout = {
    breadcrumbs: [
        {
            title: 'Refund Cases',
            href: '/refund-cases',
        },
    ],
};
