import { ChangeEvent, FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { CheckCircle2, Clock, Inbox, MessageSquareText, Search, Trash2 } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
import { Badge } from '@/components/ui/badge';
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatDate } from '@/lib/format';
import type { Paginated, SystemFeedbackRow } from '@/types';

type FeedbacksIndexProps = {
    feedbacks: Paginated<SystemFeedbackRow>;
    stats: {
        total: number;
        pending: number;
        in_review: number;
        resolved: number;
    };
    filters: {
        status: string;
        category: string;
        search: string;
    };
};

const categoryLabels: Record<string, string> = {
    saran: '💡 Saran',
    masukan: '💬 Kritik & Masukan',
    kendala_sistem: '🐛 Kendala Sistem',
    bantuan_operasional: '🤝 Bantuan Operasional',
    lainnya: '📌 Lainnya',
};

const roleLabels: Record<string, string> = {
    buyer: 'Pembeli 🛒',
    seller: 'Penjual UMK 🏬',
    assistant: 'Asisten UMK 🤝',
    admin: 'Admin 🛡️',
};

export default function FeedbacksIndex({ feedbacks, stats, filters }: FeedbacksIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');
    const [category, setCategory] = useState(filters.category || '');

    // Modal state
    const [selectedItem, setSelectedItem] = useState<SystemFeedbackRow | null>(null);
    const [newStatus, setNewStatus] = useState<string>('pending');
    const [adminNotes, setAdminNotes] = useState<string>('');
    const [isUpdating, setIsUpdating] = useState(false);

    // Delete confirm modal state
    const [deletingId, setDeletingId] = useState<string | null>(null);
    const [isDeleting, setIsDeleting] = useState(false);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get(
            '/system-feedbacks',
            { search, status, category },
            { preserveState: true, replace: true }
        );
    }

    function openReviewModal(item: SystemFeedbackRow) {
        setSelectedItem(item);
        setNewStatus(item.status);
        setAdminNotes(item.admin_notes || '');
    }

    function handleSaveReview(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        if (!selectedItem) return;

        setIsUpdating(true);
        router.patch(
            `/system-feedbacks/${selectedItem.id}`,
            {
                status: newStatus,
                admin_notes: adminNotes,
                reason: `Update feedback status to ${newStatus}`,
            },
            {
                preserveScroll: true,
                onSuccess: () => {
                    setSelectedItem(null);
                    setIsUpdating(false);
                },
                onError: () => setIsUpdating(false),
            }
        );
    }

    function handleDelete() {
        if (!deletingId) return;

        setIsDeleting(true);
        router.delete(`/system-feedbacks/${deletingId}`, {
            preserveScroll: true,
            onSuccess: () => {
                setDeletingId(null);
                setIsDeleting(false);
            },
            onError: () => setIsDeleting(false),
        });
    }

    return (
        <>
            <Head title="Kritik & Masukan Sistem" />
            <div className="flex flex-1 flex-col gap-6 p-6">
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Kritik & Masukan Sistem</h1>
                    <p className="text-sm text-muted-foreground">
                        Pusat pengelolaan saran, kritik, dan laporan kendala dari pengguna (Pembeli, UMK, & Asisten).
                    </p>
                </div>

                {/* Summary Metrics */}
                <div className="grid gap-4 md:grid-cols-4">
                    <Card>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">Total Masukan</CardTitle>
                            <Inbox className="h-4 w-4 text-muted-foreground" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-2xl font-bold">{stats.total}</div>
                            <p className="text-xs text-muted-foreground">Semua tiket yang masuk</p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">Menunggu Tindak Lanjut</CardTitle>
                            <Clock className="h-4 w-4 text-amber-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-2xl font-bold text-amber-600">{stats.pending}</div>
                            <p className="text-xs text-muted-foreground">Perlu direview admin</p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">Sedang Ditinjau</CardTitle>
                            <MessageSquareText className="h-4 w-4 text-blue-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-2xl font-bold text-blue-600">{stats.in_review}</div>
                            <p className="text-xs text-muted-foreground">Dalam proses evaluasi</p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium">Telah Selesai</CardTitle>
                            <CheckCircle2 className="h-4 w-4 text-emerald-500" />
                        </CardHeader>
                        <CardContent>
                            <div className="text-2xl font-bold text-emerald-600">{stats.resolved}</div>
                            <p className="text-xs text-muted-foreground">Telah ditanggapi / tuntas</p>
                        </CardContent>
                    </Card>
                </div>

                {/* Filter Toolbar */}
                <Card>
                    <CardHeader className="pb-3">
                        <CardTitle className="text-base">Filter & Pencarian</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <div className="flex-1">
                                <Input
                                    placeholder="Cari topik, pesan, nama pengguna, atau no HP..."
                                    value={search}
                                    onChange={(e: ChangeEvent<HTMLInputElement>) => setSearch(e.target.value)}
                                />
                            </div>
                            <select
                                className="h-9 rounded-md border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                                value={category}
                                onChange={(e: ChangeEvent<HTMLSelectElement>) => setCategory(e.target.value)}
                            >
                                <option value="">Semua Kategori</option>
                                <option value="saran">💡 Saran Pengembangan</option>
                                <option value="masukan">💬 Kritik & Masukan</option>
                                <option value="kendala_sistem">🐛 Kendala Sistem / Bug</option>
                                <option value="bantuan_operasional">🤝 Bantuan Operasional</option>
                                <option value="lainnya">📌 Lainnya</option>
                            </select>
                            <select
                                className="h-9 rounded-md border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                                value={status}
                                onChange={(e: ChangeEvent<HTMLSelectElement>) => setStatus(e.target.value)}
                            >
                                <option value="">Semua Status</option>
                                <option value="pending">Menunggu (Pending)</option>
                                <option value="in_review">Sedang Ditinjau</option>
                                <option value="resolved">Selesai (Resolved)</option>
                                <option value="rejected">Ditolak (Rejected)</option>
                            </select>
                            <Button type="submit" className="gap-2">
                                <Search className="h-4 w-4" />
                                Filter
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                {/* Data Table */}
                <Card>
                    <CardContent className="p-0">
                        <div className="overflow-x-auto">
                            <table className="w-full text-left text-sm">
                                <thead className="border-b bg-muted/50 text-xs font-medium text-muted-foreground uppercase">
                                    <tr>
                                        <th className="px-4 py-3">Pengirim</th>
                                        <th className="px-4 py-3">Kategori</th>
                                        <th className="px-4 py-3">Topik & Pesan</th>
                                        <th className="px-4 py-3">Status</th>
                                        <th className="px-4 py-3">Waktu</th>
                                        <th className="px-4 py-3 text-right">Aksi</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {feedbacks.data.length === 0 ? (
                                        <tr>
                                            <td colSpan={6} className="py-10 text-center text-muted-foreground">
                                                Tidak ada data masukan sistem yang sesuai filter.
                                            </td>
                                        </tr>
                                    ) : (
                                        feedbacks.data.map((item) => (
                                            <tr key={item.id} className="hover:bg-muted/30 transition-colors">
                                                <td className="px-4 py-3">
                                                    <div className="font-semibold text-foreground">
                                                        {item.user_name || 'Pengguna Anonim'}
                                                    </div>
                                                    <div className="text-xs text-muted-foreground">
                                                        {item.user_phone || item.user_username || '-'}
                                                    </div>
                                                    <Badge variant="outline" className="mt-1 text-[10px] px-1.5 py-0">
                                                        {roleLabels[item.user_role] || item.user_role}
                                                    </Badge>
                                                </td>
                                                <td className="px-4 py-3">
                                                    <Badge variant="secondary" className="font-normal text-xs">
                                                        {categoryLabels[item.category] || item.category}
                                                    </Badge>
                                                </td>
                                                <td className="px-4 py-3 max-w-xs md:max-w-md">
                                                    <div className="font-medium text-foreground truncate">
                                                        {item.subject}
                                                    </div>
                                                    <div className="text-xs text-muted-foreground line-clamp-2 mt-0.5">
                                                        {item.message}
                                                    </div>
                                                    {item.admin_notes && (
                                                        <div className="mt-1 text-[11px] text-blue-600 bg-blue-50 dark:bg-blue-950/40 px-2 py-0.5 rounded inline-block">
                                                            Catatan Admin: {item.admin_notes}
                                                        </div>
                                                    )}
                                                </td>
                                                <td className="px-4 py-3">
                                                    <StatusBadge status={item.status} />
                                                </td>
                                                <td className="px-4 py-3 text-xs text-muted-foreground whitespace-nowrap">
                                                    {formatDate(item.created_at)}
                                                </td>
                                                <td className="px-4 py-3 text-right whitespace-nowrap space-x-2">
                                                    <Button
                                                        size="sm"
                                                        variant="outline"
                                                        onClick={() => openReviewModal(item)}
                                                    >
                                                        Tinjau
                                                    </Button>
                                                    <Button
                                                        size="sm"
                                                        variant="ghost"
                                                        className="text-destructive hover:bg-destructive/10"
                                                        onClick={() => setDeletingId(item.id)}
                                                    >
                                                        <Trash2 className="h-4 w-4" />
                                                    </Button>
                                                </td>
                                            </tr>
                                        ))
                                    )}
                                </tbody>
                            </table>
                        </div>
                        <div className="p-4 border-t">
                            <Pagination links={feedbacks.links} />
                        </div>
                    </CardContent>
                </Card>
            </div>

            {/* Review & Respond Dialog */}
            <Dialog open={!!selectedItem} onOpenChange={(open: boolean) => !open && setSelectedItem(null)}>
                <DialogContent className="max-w-lg">
                    <DialogHeader>
                        <DialogTitle>Tinjau & Tanggapi Masukan Sistem</DialogTitle>
                        <DialogDescription>
                            Perbarui status penyelesaian dan berikan catatan tanggapan untuk pengguna.
                        </DialogDescription>
                    </DialogHeader>

                    {selectedItem && (
                        <form onSubmit={handleSaveReview} className="space-y-4">
                            <div className="rounded-lg bg-muted/50 p-3 text-xs space-y-1.5 border">
                                <div className="flex justify-between">
                                    <span className="text-muted-foreground">Pengirim:</span>
                                    <span className="font-semibold">{selectedItem.user_name || '-'} ({roleLabels[selectedItem.user_role] || selectedItem.user_role})</span>
                                </div>
                                <div className="flex justify-between">
                                    <span className="text-muted-foreground">Kontak:</span>
                                    <span>{selectedItem.user_phone || '-'}</span>
                                </div>
                                <div className="flex justify-between">
                                    <span className="text-muted-foreground">Kategori:</span>
                                    <span>{categoryLabels[selectedItem.category] || selectedItem.category}</span>
                                </div>
                                <div className="flex justify-between">
                                    <span className="text-muted-foreground">Waktu Masuk:</span>
                                    <span>{formatDate(selectedItem.created_at)}</span>
                                </div>
                            </div>

                            <div>
                                <Label className="text-xs text-muted-foreground">Subjek / Topik</Label>
                                <div className="font-semibold text-sm mt-0.5">{selectedItem.subject}</div>
                            </div>

                            <div>
                                <Label className="text-xs text-muted-foreground">Isi Pesan Masukan</Label>
                                <div className="mt-1 rounded-md border bg-muted/20 p-3 text-sm leading-relaxed max-h-40 overflow-y-auto whitespace-pre-wrap">
                                    {selectedItem.message}
                                </div>
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="status">Status Penanganan</Label>
                                <select
                                    id="status"
                                    className="w-full h-9 rounded-md border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                                    value={newStatus}
                                    onChange={(e: ChangeEvent<HTMLSelectElement>) => setNewStatus(e.target.value)}
                                >
                                    <option value="pending">Menunggu (Pending)</option>
                                    <option value="in_review">Sedang Ditinjau (In Review)</option>
                                    <option value="resolved">Selesai (Resolved)</option>
                                    <option value="rejected">Ditolak (Rejected)</option>
                                </select>
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="admin_notes">Tanggapan / Catatan Admin</Label>
                                <textarea
                                    id="admin_notes"
                                    rows={3}
                                    className="w-full rounded-md border bg-background p-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary placeholder:text-muted-foreground"
                                    placeholder="Tuliskan catatan internal atau tanggapan untuk pengguna..."
                                    value={adminNotes}
                                    onChange={(e: ChangeEvent<HTMLTextAreaElement>) => setAdminNotes(e.target.value)}
                                />
                            </div>

                            <DialogFooter className="gap-2">
                                <Button
                                    type="button"
                                    variant="outline"
                                    onClick={() => setSelectedItem(null)}
                                    disabled={isUpdating}
                                >
                                    Batal
                                </Button>
                                <Button type="submit" disabled={isUpdating}>
                                    {isUpdating ? 'Menyimpan...' : 'Simpan Perubahan'}
                                </Button>
                            </DialogFooter>
                        </form>
                    )}
                </DialogContent>
            </Dialog>

            {/* Confirm Delete Dialog */}
            <Dialog open={!!deletingId} onOpenChange={(open: boolean) => !open && setDeletingId(null)}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Hapus Tiket Masukan?</DialogTitle>
                        <DialogDescription>
                            Tindakan ini akan menghapus data masukan sistem secara permanen dari database.
                        </DialogDescription>
                    </DialogHeader>
                    <DialogFooter className="gap-2">
                        <Button
                            type="button"
                            variant="outline"
                            onClick={() => setDeletingId(null)}
                            disabled={isDeleting}
                        >
                            Batal
                        </Button>
                        <Button
                            type="button"
                            variant="destructive"
                            onClick={handleDelete}
                            disabled={isDeleting}
                        >
                            {isDeleting ? 'Menghapus...' : 'Hapus Sekarang'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
