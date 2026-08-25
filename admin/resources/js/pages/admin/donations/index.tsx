import { useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { formatCurrency, formatDate } from '@/lib/format';
import { HeartHandshake, CheckCircle, Store, User, ArrowRight, Trash2 } from 'lucide-react';

type Donation = {
    id: string;
    user_id: string | null;
    store_id: string;
    order_id: string | null;
    amount: string;
    donor_name: string;
    donor_email: string | null;
    donor_phone: string | null;
    note: string | null;
    status: 'paid' | 'distributed' | 'cancelled';
    created_at: string;
    store: { id: string; name: string };
    user?: { id: string; full_name: string; phone: string | null };
};

type StoreOption = {
    id: string;
    name: string;
};

type DonationsIndexProps = {
    donations: {
        data: Donation[];
        links: any[];
        current_page: number;
        last_page: number;
        total: number;
    };
    stores: StoreOption[];
    metrics: {
        total_collected: number;
        total_distributed: number;
        total_donors: number;
        total_stores_supported: number;
    };
    filters: {
        status?: string;
        store_id?: string;
    };
};

export default function DonationsIndex({ donations, stores, metrics, filters }: DonationsIndexProps) {
    const [selectedDonation, setSelectedDonation] = useState<Donation | null>(null);
    const [newStatus, setNewStatus] = useState<'paid' | 'distributed' | 'cancelled'>('distributed');
    const [statusNote, setStatusNote] = useState('');

    const handleFilterChange = (key: string, value: string) => {
        const newFilters = { ...filters, [key]: value };
        if (!value) delete (newFilters as any)[key];
        router.get('/donations', newFilters, { preserveState: true });
    };

    const handleUpdateStatus = () => {
        if (!selectedDonation) return;

        router.patch(
            `/donations/${selectedDonation.id}`,
            {
                status: newStatus,
                note: statusNote,
            },
            {
                onSuccess: () => {
                    setSelectedDonation(null);
                    setStatusNote('');
                },
            }
        );
    };

    const handleDeleteDonation = (donation: Donation) => {
        if (confirm(`Hapus catatan donasi sebesar ${formatCurrency(donation.amount)}?`)) {
            router.delete(`/donations/${donation.id}`);
        }
    };

    return (
        <>
            <Head title="Manajemen Donasi UMK" />
            <div className="flex flex-1 flex-col gap-5 p-5">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Manajemen Donasi & Dukungan UMK</h1>
                    <p className="text-sm text-muted-foreground">
                        Monitoring donasi sukarela dari pembeli dan pengelolaan penyaluran dana ke mitra toko UMK.
                    </p>
                </div>

                {/* Metrics */}
                <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-4">
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Total Donasi Terkumpul</p>
                            <h3 className="mt-1 text-2xl font-bold text-emerald-600">{formatCurrency(metrics.total_collected)}</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Siap disalurkan ke toko</p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Sudah Disalurkan</p>
                            <h3 className="mt-1 text-2xl font-bold text-blue-600">{formatCurrency(metrics.total_distributed)}</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Telah diterima toko UMK</p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Total Transaksi Donatur</p>
                            <h3 className="mt-1 text-2xl font-bold">{metrics.total_donors} Kali</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Dukungan pembeli peduli</p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Toko UMK Terbantu</p>
                            <h3 className="mt-1 text-2xl font-bold text-primary">{metrics.total_stores_supported} Mitra</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Penerima manfaat donasi</p>
                        </CardContent>
                    </Card>
                </div>

                {/* Filters */}
                <div className="flex flex-wrap items-center gap-3">
                    <select
                        value={filters.status ?? ''}
                        onChange={(e) => handleFilterChange('status', e.target.value)}
                        className="rounded-lg border border-input bg-background px-3 py-2 text-sm"
                    >
                        <option value="">Semua Status Donasi</option>
                        <option value="paid">Terkumpul / Belum Disalurkan</option>
                        <option value="distributed">Sudah Disalurkan</option>
                        <option value="cancelled">Dibatalkan</option>
                    </select>

                    <select
                        value={filters.store_id ?? ''}
                        onChange={(e) => handleFilterChange('store_id', e.target.value)}
                        className="rounded-lg border border-input bg-background px-3 py-2 text-sm"
                    >
                        <option value="">Semua Toko Penerima</option>
                        {stores.map((s) => (
                            <option key={s.id} value={s.id}>
                                {s.name}
                            </option>
                        ))}
                    </select>
                </div>

                {/* Donations Table */}
                <Card>
                    <CardHeader>
                        <CardTitle>Riwayat Donasi Masuk</CardTitle>
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[850px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Toko UMK Penerima</th>
                                    <th className="pb-3 font-medium">Donatur</th>
                                    <th className="pb-3 font-medium">Catatan / Doa</th>
                                    <th className="pb-3 font-medium">Waktu Donasi</th>
                                    <th className="pb-3 text-right font-medium">Nominal Donasi</th>
                                    <th className="pb-3 text-center font-medium">Status Penyaluran</th>
                                    <th className="pb-3 text-right font-medium">Aksi</th>
                                </tr>
                            </thead>
                            <tbody>
                                {donations.data.map((donation) => (
                                    <tr key={donation.id} className="border-b transition hover:bg-muted/30 last:border-0">
                                        <td className="py-3.5">
                                            <div className="flex items-center gap-1.5 font-semibold text-primary">
                                                <Store className="h-3.5 w-3.5" />
                                                {donation.store?.name}
                                            </div>
                                        </td>
                                        <td className="py-3.5">
                                            <div className="flex items-center gap-1.5 font-medium">
                                                <User className="h-3.5 w-3.5 text-muted-foreground" />
                                                {donation.donor_name}
                                            </div>
                                            {donation.donor_phone && (
                                                <p className="text-xs text-muted-foreground">{donation.donor_phone}</p>
                                            )}
                                        </td>
                                        <td className="py-3.5 text-xs text-muted-foreground max-w-[200px]">
                                            {donation.note ? `"${donation.note}"` : '-'}
                                        </td>
                                        <td className="py-3.5 text-xs text-muted-foreground">
                                            {formatDate(donation.created_at)}
                                        </td>
                                        <td className="py-3.5 text-right font-bold text-emerald-600">
                                            {formatCurrency(donation.amount)}
                                        </td>
                                        <td className="py-3.5 text-center">
                                            <span
                                                className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                                                    donation.status === 'distributed'
                                                        ? 'bg-blue-50 text-blue-700'
                                                        : donation.status === 'paid'
                                                          ? 'bg-emerald-50 text-emerald-700'
                                                          : 'bg-gray-100 text-gray-700'
                                                }`}
                                            >
                                                {donation.status === 'distributed' ? 'Tersalurkan' : 'Terkumpul (Siap Salur)'}
                                            </span>
                                        </td>
                                        <td className="py-3.5 text-right">
                                            <div className="flex items-center justify-end gap-1.5">
                                                <Button
                                                    size="sm"
                                                    variant="outline"
                                                    onClick={() => {
                                                        setSelectedDonation(donation);
                                                        setNewStatus(donation.status === 'paid' ? 'distributed' : 'paid');
                                                    }}
                                                    className="h-8 gap-1 text-xs"
                                                >
                                                    <ArrowRight className="h-3 w-3" /> Status
                                                </Button>
                                                <Button
                                                    size="icon"
                                                    variant="ghost"
                                                    onClick={() => handleDeleteDonation(donation)}
                                                    className="h-8 w-8 text-destructive hover:text-destructive"
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                                {donations.data.length === 0 && (
                                    <tr>
                                        <td colSpan={7} className="py-8 text-center text-muted-foreground">
                                            Belum ada data donasi tercatat.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                {/* Dialog: Update Status Penyaluran */}
                {selectedDonation && (
                    <Dialog open={Boolean(selectedDonation)} onOpenChange={() => setSelectedDonation(null)}>
                        <DialogContent className="sm:max-w-[450px]">
                            <DialogHeader>
                                <DialogTitle>Update Status Penyaluran Donasi</DialogTitle>
                                <DialogDescription>
                                    Toko Penerima: <strong>{selectedDonation.store?.name}</strong> | Nominal:{' '}
                                    <strong className="text-emerald-600">{formatCurrency(selectedDonation.amount)}</strong>
                                </DialogDescription>
                            </DialogHeader>

                            <div className="space-y-3 py-2">
                                <div>
                                    <label className="text-xs font-medium text-muted-foreground">Status Baru</label>
                                    <select
                                        value={newStatus}
                                        onChange={(e) => setNewStatus(e.target.value as any)}
                                        className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                    >
                                        <option value="paid">Terkumpul (Belum Disalurkan)</option>
                                        <option value="distributed">Sudah Disalurkan ke Toko UMK</option>
                                        <option value="cancelled">Dibatalkan / Refund</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="text-xs font-medium text-muted-foreground">Catatan Penyaluran (Opsional)</label>
                                    <input
                                        type="text"
                                        value={statusNote}
                                        onChange={(e) => setStatusNote(e.target.value)}
                                        placeholder="Contoh: Ditransfer via Rekening BCA Toko"
                                        className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                    />
                                </div>
                            </div>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setSelectedDonation(null)}>
                                    Batal
                                </Button>
                                <Button onClick={handleUpdateStatus}>
                                    Simpan Status
                                </Button>
                            </DialogFooter>
                        </DialogContent>
                    </Dialog>
                )}
            </div>
        </>
    );
}
