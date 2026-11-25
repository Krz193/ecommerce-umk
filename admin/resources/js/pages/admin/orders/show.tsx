import { Head, Link } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';

type TrackingHistoryEvent = {
    status?: string;
    checkpoint_name?: string | null;
    note?: string | null;
    role?: string | null;
    driver_name?: string | null;
    latitude?: number | null;
    longitude?: number | null;
    timestamp?: string | null;
};

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
    shipping_notes: string | null;
    shipping_latitude: number | null;
    shipping_longitude: number | null;
    shipping_provider: string | null;
    tracking_number: string | null;
    courier_name: string | null;
    courier_code: string | null;
    courier_service_type: string | null;
    biteship_order_id: string | null;
    waybill_id: string | null;
    driver_id: string | null;
    driver_name: string | null;
    driver_phone: string | null;
    driver_vehicle_plate: string | null;
    driver_latitude: number | null;
    driver_longitude: number | null;
    driver_last_updated: string | null;
    tracking_status: string | null;
    tracking_url: string | null;
    tracking_history: TrackingHistoryEvent[] | string | null;
    placed_at: string | null;
    paid_at: string | null;
    completed_at: string | null;
    cancelled_at: string | null;
    created_at: string;
    store_name: string;
    store_phone: string | null;
    store_address: string | null;
    store_city: string | null;
    store_province: string | null;
    store_postal_code: string | null;
    store_notes: string | null;
    store_latitude: number | null;
    store_longitude: number | null;
    origin_contact_name: string | null;
    origin_phone: string | null;
    origin_address: string | null;
    origin_city: string | null;
    origin_postal_code: string | null;
    origin_notes: string | null;
    origin_latitude: number | null;
    origin_longitude: number | null;
    seller_owner_name: string | null;
    seller_owner_phone: string | null;
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

function parseTrackingHistory(raw: OrderDetail['tracking_history']): TrackingHistoryEvent[] {
    if (Array.isArray(raw)) {
        return raw;
    }

    if (typeof raw === 'string' && raw.trim() !== '') {
        try {
            const parsed = JSON.parse(raw);

            return Array.isArray(parsed) ? parsed : [];
        } catch {
            return [];
        }
    }

    return [];
}

function formatCoordinates(lat: number | null | undefined, lng: number | null | undefined): string {
    if (typeof lat !== 'number' || typeof lng !== 'number' || Number.isNaN(lat) || Number.isNaN(lng)) {
        return '-';
    }

    return `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
}

export default function OrderShow({ order, items }: OrderShowProps) {
    const originName = order.origin_contact_name || order.store_name || '-';
    const originPhone = order.origin_phone || order.store_phone || order.seller_owner_phone || '-';
    const originAddress = order.origin_address || order.store_address || '-';
    const originCity = order.origin_city || order.store_city || '';
    const originPostal = order.origin_postal_code || order.store_postal_code || '';
    const originNotes = order.origin_notes || order.store_notes || '-';
    const originLat = order.origin_latitude ?? order.store_latitude;
    const originLng = order.origin_longitude ?? order.store_longitude;

    const courierCodeLower = (order.courier_code || '').toLowerCase();
    const isInstant =
        order.courier_service_type === 'instant' ||
        order.courier_service_type === 'same_day' ||
        courierCodeLower.includes('gojek') ||
        courierCodeLower.includes('grab') ||
        courierCodeLower.includes('ojek');
    const isBiteship =
        Boolean(order.biteship_order_id) ||
        (!order.driver_id &&
            ['gojek', 'grab', 'jne', 'sicepat', 'jnt', 'anteraja', 'paxel', 'ninja', 'lion', 'pos', 'tiki'].includes(
                courierCodeLower,
            ));

    const trackingHistory = parseTrackingHistory(order.tracking_history);

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
                    <div className="flex gap-2">
                        <Button asChild>
                            <Link href={`/refund-cases/create?order_id=${order.id}`}>Create Refund Case</Link>
                        </Button>
                        <Button asChild variant="outline">
                            <Link href="/orders">Back to orders</Link>
                        </Button>
                    </div>
                </div>

                <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                    <Card>
                        <CardHeader><CardTitle>Seller / Pengirim (Origin)</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Store / Sender Name" value={originName} />
                            <Info label="Store Owner" value={order.seller_owner_name || '-'} />
                            <Info label="Sender Phone" value={originPhone} />
                            <Info
                                label="Origin Address"
                                value={[originAddress, originCity, originPostal].filter(Boolean).join(', ') || '-'}
                            />
                            <Info label="Origin Notes / Patokan" value={originNotes} />
                            <Info label="Origin GPS" value={formatCoordinates(originLat, originLng)} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Customer (Destination)</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Buyer" value={order.buyer_name || '-'} />
                            <Info label="Buyer Phone" value={order.buyer_phone || '-'} />
                            <Info label="Shipping Name" value={order.shipping_name} />
                            <Info label="Shipping Phone" value={order.shipping_phone} />
                            <Info
                                label="Destination Address"
                                value={`${order.shipping_address}, ${order.shipping_city} ${order.shipping_postal_code || ''}`}
                            />
                            <Info label="Destination Notes / Patokan" value={order.shipping_notes || '-'} />
                            <Info
                                label="Destination GPS"
                                value={formatCoordinates(order.shipping_latitude, order.shipping_longitude)}
                            />
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
                        <CardHeader>
                            <CardTitle className="flex flex-wrap items-center justify-between gap-2">
                                <span>Shipment & Logistics</span>
                                <div className="flex gap-1">
                                    <Badge variant="outline">{isInstant ? 'Instant' : 'Ekspedisi'}</Badge>
                                    <Badge variant="secondary">{isBiteship ? 'Biteship' : 'Mitra Lokal'}</Badge>
                                </div>
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Courier / Expedition" value={order.courier_name || order.shipping_provider || '-'} />
                            <Info label="Shipping Fee" value={formatCurrency(order.shipping_cost)} />
                            <Info label="Tracking / Waybill" value={order.waybill_id || order.tracking_number || '-'} />
                            {order.biteship_order_id && <Info label="Biteship Order ID" value={order.biteship_order_id} />}
                            {order.driver_name && <Info label="Driver Name" value={order.driver_name} />}
                            {order.driver_phone && <Info label="Driver Phone" value={order.driver_phone} />}
                            {order.driver_vehicle_plate && <Info label="Vehicle / Plate" value={order.driver_vehicle_plate} />}
                            {(order.driver_latitude != null && order.driver_longitude != null) && (
                                <Info
                                    label="Driver Live GPS"
                                    value={formatCoordinates(order.driver_latitude, order.driver_longitude)}
                                />
                            )}
                            {order.driver_last_updated && (
                                <Info label="Driver GPS Updated" value={formatDate(order.driver_last_updated)} />
                            )}
                            {order.tracking_status && <Info label="Tracking Status" value={order.tracking_status.toUpperCase()} />}
                            {order.tracking_url && (
                                <div>
                                    <div className="text-xs text-muted-foreground">Live Tracking Link</div>
                                    <a
                                        href={order.tracking_url}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="text-sm font-medium text-primary underline break-all"
                                    >
                                        {order.tracking_url}
                                    </a>
                                </div>
                            )}
                            <Info label="Placed At" value={formatDate(order.placed_at)} />
                            <Info label="Order Paid At" value={formatDate(order.paid_at)} />
                            <Info label="Completed At" value={formatDate(order.completed_at)} />
                            <Info label="Cancelled At" value={formatDate(order.cancelled_at)} />
                        </CardContent>
                    </Card>
                </div>

                {trackingHistory.length > 0 && (
                    <Card>
                        <CardHeader><CardTitle>Per-Point Tracking History</CardTitle></CardHeader>
                        <CardContent className="space-y-4">
                            {trackingHistory.map((ev, index) => (
                                <div
                                    key={`${ev.timestamp || 'ts'}-${ev.status || 'st'}-${index}`}
                                    className="flex flex-col gap-1 border-l-2 border-primary/40 pl-4 text-sm"
                                >
                                    <div className="flex flex-wrap items-center gap-2">
                                        <span className="font-semibold">
                                            #{index + 1} · {ev.checkpoint_name || (ev.status ? ev.status.toUpperCase() : 'UPDATE')}
                                        </span>
                                        {ev.status && <Badge variant="outline">{ev.status}</Badge>}
                                        {ev.timestamp && (
                                            <span className="text-xs text-muted-foreground">{formatDate(ev.timestamp)}</span>
                                        )}
                                    </div>
                                    {ev.note && <p className="text-muted-foreground">{ev.note}</p>}
                                    <div className="flex flex-wrap gap-3 text-xs text-muted-foreground">
                                        {ev.driver_name && <span>Driver: {ev.driver_name}</span>}
                                        {ev.role && <span>Role: {ev.role}</span>}
                                        {typeof ev.latitude === 'number' && typeof ev.longitude === 'number' && (
                                            <span>GPS: {formatCoordinates(ev.latitude, ev.longitude)}</span>
                                        )}
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                )}

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
