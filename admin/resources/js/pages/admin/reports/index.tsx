import { useState } from 'react';
import { Head } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';

type ReportsIndexProps = {
    financeSummary: {
        paid_revenue: number;
        application_fee: number;
        total_shipping: number;
        total_donations: number;
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
    shippingReports: Array<{
        store_id: string;
        store_name: string;
        courier_name: string;
        total_shipments: number;
        shipped_count: number;
        delivered_count: number;
        total_shipping_fee: string;
    }>;
    assistantReports: Array<{
        assistant_id: string;
        assistant_name: string;
        assistant_phone: string | null;
        store_id: string;
        store_name: string;
        assigned_at: string;
        total_logs: number;
        total_contents_created: number;
    }>;
    donationReports: Array<{
        store_id: string;
        store_name: string;
        total_donors: number;
        total_donations_collected: string;
        last_donation_at: string | null;
    }>;
};

export default function ReportsIndex({
    financeSummary,
    storeSummary,
    storeReports,
    stockReports,
    shippingReports,
    assistantReports,
    donationReports,
}: ReportsIndexProps) {
    const [activeTab, setActiveTab] = useState<'sales' | 'stock' | 'shipping' | 'assistants' | 'donations'>('sales');

    return (
        <>
            <Head title="Laporan Platform UMK" />
            <div className="flex flex-1 flex-col gap-5 p-5">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Laporan & Analitik Platform</h1>
                    <p className="text-sm text-muted-foreground">
                        Monitoring komprehensif performa penjualan, stok produk, logistik kurir, kinerja asisten, dan donasi UMK.
                    </p>
                </div>

                {/* Top Metrics Grid */}
                <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-4 lg:grid-cols-6">
                    <Metric title="Total Toko UMK" value={String(storeSummary.total)} subtitle={`${storeSummary.active} aktif`} />
                    <Metric title="Total Omset Penjualan" value={formatCurrency(financeSummary.paid_revenue)} highlight />
                    <Metric title="Pendapatan Platform" value={formatCurrency(financeSummary.application_fee)} />
                    <Metric title="Total Ongkir Logistik" value={formatCurrency(financeSummary.total_shipping)} />
                    <Metric title="Total Donasi Terkumpul" value={formatCurrency(financeSummary.total_donations)} color="text-green-600" />
                    <Metric title="Pesanan Sukses" value={`${financeSummary.paid_orders} Transaksi`} subtitle={`${financeSummary.pending_payments} pending`} />
                </div>

                {/* Custom Tab Navigation */}
                <div className="flex flex-wrap gap-2 border-b pb-2">
                    <button
                        onClick={() => setActiveTab('sales')}
                        className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
                            activeTab === 'sales' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/50 text-muted-foreground hover:bg-muted'
                        }`}
                    >
                        🏪 Toko & Penjualan UMK
                    </button>
                    <button
                        onClick={() => setActiveTab('stock')}
                        className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
                            activeTab === 'stock' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/50 text-muted-foreground hover:bg-muted'
                        }`}
                    >
                        ⚠️ Stok Menipis
                    </button>
                    <button
                        onClick={() => setActiveTab('shipping')}
                        className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
                            activeTab === 'shipping' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/50 text-muted-foreground hover:bg-muted'
                        }`}
                    >
                        🚚 Logistik & Ekspedisi
                    </button>
                    <button
                        onClick={() => setActiveTab('assistants')}
                        className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
                            activeTab === 'assistants' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/50 text-muted-foreground hover:bg-muted'
                        }`}
                    >
                        🤝 Kinerja Asisten UMK
                    </button>
                    <button
                        onClick={() => setActiveTab('donations')}
                        className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
                            activeTab === 'donations' ? 'bg-primary text-primary-foreground shadow-sm' : 'bg-muted/50 text-muted-foreground hover:bg-muted'
                        }`}
                    >
                        ❤️ Donasi UMK
                    </button>
                </div>

                {/* Tab 1: Sales & Store Performance */}
                {activeTab === 'sales' && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Laporan Penjualan & Performa Toko UMK</CardTitle>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[850px] text-sm">
                                <thead className="border-b text-left text-muted-foreground">
                                    <tr>
                                        <th className="pb-3 font-medium">Nama Toko</th>
                                        <th className="pb-3 font-medium">Status</th>
                                        <th className="pb-3 text-center font-medium">Total Produk</th>
                                        <th className="pb-3 text-center font-medium">Tayang</th>
                                        <th className="pb-3 text-center font-medium">Pesanan</th>
                                        <th className="pb-3 text-center font-medium">Pembeli Unik</th>
                                        <th className="pb-3 text-right font-medium">Total Omset</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {storeReports.map((store) => (
                                        <tr key={store.id} className="border-b transition hover:bg-muted/30 last:border-0">
                                            <td className="py-3 font-semibold">{store.name}</td>
                                            <td className="py-3"><StatusBadge status={store.status} /></td>
                                            <td className="py-3 text-center">{store.product_count}</td>
                                            <td className="py-3 text-center font-medium text-green-700">{store.published_product_count}</td>
                                            <td className="py-3 text-center">{store.order_count}</td>
                                            <td className="py-3 text-center">{store.buyer_count}</td>
                                            <td className="py-3 text-right font-bold text-primary">{formatCurrency(store.paid_revenue)}</td>
                                        </tr>
                                    ))}
                                    {storeReports.length === 0 && (
                                        <tr>
                                            <td colSpan={7} className="py-6 text-center text-muted-foreground">Belum ada data toko.</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}

                {/* Tab 2: Stock Health */}
                {activeTab === 'stock' && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Laporan Peringatan Stok Menipis (&le; 10 Item)</CardTitle>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[760px] text-sm">
                                <thead className="border-b text-left text-muted-foreground">
                                    <tr>
                                        <th className="pb-3 font-medium">Produk</th>
                                        <th className="pb-3 font-medium">Toko UMK</th>
                                        <th className="pb-3 font-medium">Kategori</th>
                                        <th className="pb-3 font-medium">Status</th>
                                        <th className="pb-3 text-center font-medium">Sisa Stok</th>
                                        <th className="pb-3 text-right font-medium">Harga Satuan</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {stockReports.map((product) => (
                                        <tr key={product.id} className="border-b transition hover:bg-muted/30 last:border-0">
                                            <td className="py-3 font-semibold">{product.name}</td>
                                            <td className="py-3 text-muted-foreground">{product.store_name}</td>
                                            <td className="py-3">{product.category_name ?? '-'}</td>
                                            <td className="py-3"><StatusBadge status={product.status} /></td>
                                            <td className="py-3 text-center">
                                                <span className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-bold ${
                                                    product.stock <= 2 ? 'bg-red-100 text-red-800' : 'bg-orange-100 text-orange-800'
                                                }`}>
                                                    {product.stock} pcs
                                                </span>
                                            </td>
                                            <td className="py-3 text-right font-medium">{formatCurrency(product.price)}</td>
                                        </tr>
                                    ))}
                                    {stockReports.length === 0 && (
                                        <tr>
                                            <td colSpan={6} className="py-6 text-center text-muted-foreground">Semua stok produk dalam kondisi aman.</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}

                {/* Tab 3: Shipping & Logistics per UMK */}
                {activeTab === 'shipping' && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Laporan Pengiriman & Ekspedisi per Toko UMK</CardTitle>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[850px] text-sm">
                                <thead className="border-b text-left text-muted-foreground">
                                    <tr>
                                        <th className="pb-3 font-medium">Toko UMK</th>
                                        <th className="pb-3 font-medium">Layanan Kurir</th>
                                        <th className="pb-3 text-center font-medium">Total Paket</th>
                                        <th className="pb-3 text-center font-medium">Dalam Pengiriman</th>
                                        <th className="pb-3 text-center font-medium">Selesai/Terkirim</th>
                                        <th className="pb-3 text-right font-medium">Total Ongkir Terbayar</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {shippingReports.map((ship, idx) => (
                                        <tr key={idx} className="border-b transition hover:bg-muted/30 last:border-0">
                                            <td className="py-3 font-semibold">{ship.store_name}</td>
                                            <td className="py-3">
                                                <span className="inline-flex items-center gap-1.5 rounded-md bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-800">
                                                    📦 {ship.courier_name}
                                                </span>
                                            </td>
                                            <td className="py-3 text-center font-bold">{ship.total_shipments}</td>
                                            <td className="py-3 text-center text-blue-600 font-medium">{ship.shipped_count}</td>
                                            <td className="py-3 text-center text-green-600 font-bold">{ship.delivered_count}</td>
                                            <td className="py-3 text-right font-semibold">{formatCurrency(ship.total_shipping_fee)}</td>
                                        </tr>
                                    ))}
                                    {shippingReports.length === 0 && (
                                        <tr>
                                            <td colSpan={6} className="py-6 text-center text-muted-foreground">Belum ada data pengiriman ekspedisi.</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}

                {/* Tab 4: Assistant UMK Performance */}
                {activeTab === 'assistants' && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Laporan Kinerja & Pendampingan Asisten UMK</CardTitle>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[850px] text-sm">
                                <thead className="border-b text-left text-muted-foreground">
                                    <tr>
                                        <th className="pb-3 font-medium">Nama Asisten</th>
                                        <th className="pb-3 font-medium">Kontak</th>
                                        <th className="pb-3 font-medium">Toko yang Didampingi</th>
                                        <th className="pb-3 text-center font-medium">Log Aktivitas</th>
                                        <th className="pb-3 text-center font-medium">Konten/Promosi Dibuat</th>
                                        <th className="pb-3 text-right font-medium">Mulai Mendampingi</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {assistantReports.map((ast) => (
                                        <tr key={`${ast.assistant_id}-${ast.store_id}`} className="border-b transition hover:bg-muted/30 last:border-0">
                                            <td className="py-3 font-semibold">{ast.assistant_name}</td>
                                            <td className="py-3 text-muted-foreground">{ast.assistant_phone ?? '-'}</td>
                                            <td className="py-3 font-medium text-primary">{ast.store_name}</td>
                                            <td className="py-3 text-center">
                                                <span className="inline-flex rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-bold text-emerald-700">
                                                    {ast.total_logs} Kegiatan
                                                </span>
                                            </td>
                                            <td className="py-3 text-center font-medium">{ast.total_contents_created} Banner</td>
                                            <td className="py-3 text-right text-xs text-muted-foreground">{formatDate(ast.assigned_at)}</td>
                                        </tr>
                                    ))}
                                    {assistantReports.length === 0 && (
                                        <tr>
                                            <td colSpan={6} className="py-6 text-center text-muted-foreground">Belum ada data asisten UMK aktif.</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}

                {/* Tab 5: Donation Reports */}
                {activeTab === 'donations' && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Laporan Donasi & Dukungan UMK</CardTitle>
                        </CardHeader>
                        <CardContent className="overflow-x-auto">
                            <table className="w-full min-w-[760px] text-sm">
                                <thead className="border-b text-left text-muted-foreground">
                                    <tr>
                                        <th className="pb-3 font-medium">Toko UMK Penerima</th>
                                        <th className="pb-3 text-center font-medium">Total Donatur</th>
                                        <th className="pb-3 text-right font-medium">Total Donasi Terkumpul</th>
                                        <th className="pb-3 text-right font-medium">Donasi Terakhir</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {donationReports.map((don) => (
                                        <tr key={don.store_id} className="border-b transition hover:bg-muted/30 last:border-0">
                                            <td className="py-3 font-semibold">{don.store_name}</td>
                                            <td className="py-3 text-center font-medium">{don.total_donors} Donatur</td>
                                            <td className="py-3 text-right font-bold text-emerald-600">{formatCurrency(don.total_donations_collected)}</td>
                                            <td className="py-3 text-right text-xs text-muted-foreground">
                                                {don.last_donation_at ? formatDate(don.last_donation_at) : '-'}
                                            </td>
                                        </tr>
                                    ))}
                                    {donationReports.length === 0 && (
                                        <tr>
                                            <td colSpan={4} className="py-6 text-center text-muted-foreground">Belum ada data donasi tercatat.</td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </CardContent>
                    </Card>
                )}
            </div>
        </>
    );
}

function Metric({
    title,
    value,
    subtitle,
    highlight,
    color,
}: {
    title: string;
    value: string;
    subtitle?: string;
    highlight?: boolean;
    color?: string;
}) {
    return (
        <Card className={`overflow-hidden transition-all ${highlight ? 'border-primary/40 shadow-sm' : ''}`}>
            <CardContent className="p-4">
                <p className="text-xs font-medium text-muted-foreground">{title}</p>
                <h3 className={`mt-1.5 text-xl font-bold tracking-tight ${color ? color : (highlight ? 'text-primary' : '')}`}>
                    {value}
                </h3>
                {subtitle && <p className="mt-1 text-[11px] text-muted-foreground">{subtitle}</p>}
            </CardContent>
        </Card>
    );
}
