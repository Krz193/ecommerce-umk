import { Head, router } from '@inertiajs/react';
import { Bell, Search, Send } from 'lucide-react';
import type { FormEvent} from 'react';
import { useState } from 'react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { Pagination } from '@/components/admin/pagination';
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
import type { NotificationRow, Paginated } from '@/types';

type UserOption = {
    id: string;
    full_name: string | null;
    role: string;
    email: string | null;
};

type NotificationsIndexProps = {
    notifications: Paginated<NotificationRow>;
    stats: {
        total: number;
        unread: number;
        promo: number;
        transaction: number;
        system: number;
    };
    filters: {
        search: string;
        category: string;
        read_state: string;
    };
    users: UserOption[];
};

const CATEGORY_LABELS: Record<string, string> = {
    promo: 'Promo & Flash Sale',
    transaction: 'Transaksi & Order',
    system: 'Sistem & Informasi',
};

const ROUTE_PRESETS = [
    { label: 'Beranda / Flash Sale (/home)', value: '/home' },
    { label: 'Daftar Pesanan Pembeli (/orders)', value: '/orders' },
    { label: 'Dashboard Toko Seller (/seller/store)', value: '/seller/store' },
    { label: 'Dashboard Asisten (/assistant/dashboard)', value: '/assistant/dashboard' },
    { label: 'Pusat Bantuan & Masukan (/feedback)', value: '/feedback' },
];

export default function NotificationsIndex({
    notifications,
    stats,
    filters,
    users,
}: NotificationsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [categoryFilter, setCategoryFilter] = useState(filters.category || '');
    const [readState, setReadState] = useState(filters.read_state || '');

    const [isOpen, setIsOpen] = useState(false);
    const [targetMode, setTargetMode] = useState<'all' | 'role' | 'user'>('all');
    const [targetRole, setTargetRole] = useState('buyer');
    const [targetUserId, setTargetUserId] = useState(users[0]?.id || '');
    const [category, setCategory] = useState<'promo' | 'system' | 'transaction'>('promo');
    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [targetRoute, setTargetRoute] = useState('/home');
    const [isSubmitting, setIsSubmitting] = useState(false);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get(
            '/notifications',
            { search, category: categoryFilter, read_state: readState },
            { preserveState: true, replace: true },
        );
    }

    function openBroadcastModal() {
        setTargetMode('all');
        setTargetRole('buyer');
        setTargetUserId(users[0]?.id || '');
        setCategory('promo');
        setTitle('');
        setBody('');
        setTargetRoute('/home');
        setIsOpen(true);
    }

    function handleBroadcast(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        setIsSubmitting(true);

        router.post(
            '/notifications',
            {
                target_mode: targetMode,
                target_role: targetMode === 'role' ? targetRole : null,
                target_user_id: targetMode === 'user' ? targetUserId : null,
                category,
                title,
                body,
                target_route: targetRoute || null,
            },
            {
                preserveScroll: true,
                onSuccess: () => {
                    setIsOpen(false);
                    setIsSubmitting(false);
                },
                onError: () => setIsSubmitting(false),
            },
        );
    }

    function handleDelete(row: NotificationRow) {
        router.delete(`/notifications/${row.id}`, { preserveScroll: true });
    }

    return (
        <>
            <Head title="Broadcast & Log Notifikasi" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-center">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-semibold">
                            <Bell className="h-6 w-6 text-primary" />
                            Broadcast &amp; Log Notifikasi
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Kirim notifikasi manual ke pengguna Flutter atau pantau notifikasi otomatis dari sistem.
                        </p>
                    </div>
                    <Button onClick={openBroadcastModal}>
                        <Send className="mr-2 h-4 w-4" />
                        Kirim Broadcast
                    </Button>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Total Notifikasi</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">{stats.total}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Belum Dibaca</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold text-amber-600">{stats.unread}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Transaksi</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">{stats.transaction}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Promo</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">{stats.promo}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Sistem</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">{stats.system}</CardContent>
                    </Card>
                </div>

                <Card>
                    <CardContent className="pt-6">
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <div className="relative flex-1">
                                <Search className="absolute top-2.5 left-3 h-4 w-4 text-muted-foreground" />
                                <Input
                                    value={search}
                                    onChange={(e) => setSearch(e.target.value)}
                                    placeholder="Cari judul, isi pesan, nama, atau email penerima..."
                                    className="pl-9"
                                />
                            </div>
                            <select
                                value={categoryFilter}
                                onChange={(e) => setCategoryFilter(e.target.value)}
                                className="h-9 rounded-md border border-input bg-background px-3 text-sm"
                            >
                                <option value="">Semua Kategori</option>
                                <option value="transaction">Transaksi</option>
                                <option value="promo">Promo</option>
                                <option value="system">Sistem</option>
                            </select>
                            <select
                                value={readState}
                                onChange={(e) => setReadState(e.target.value)}
                                className="h-9 rounded-md border border-input bg-background px-3 text-sm"
                            >
                                <option value="">Semua Status Baca</option>
                                <option value="unread">Belum Dibaca</option>
                                <option value="read">Sudah Dibaca</option>
                            </select>
                            <Button type="submit" variant="secondary">Filter</Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardContent className="overflow-x-auto pt-6">
                        <table className="w-full text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="pb-3 pr-4">Penerima</th>
                                    <th className="pb-3 pr-4">Kategori</th>
                                    <th className="pb-3 pr-4">Pesan</th>
                                    <th className="pb-3 pr-4">Status</th>
                                    <th className="pb-3 pr-4">Waktu</th>
                                    <th className="pb-3 text-right">Aksi</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y">
                                {notifications.data.map((row) => (
                                    <tr key={row.id} className="align-top">
                                        <td className="py-3 pr-4">
                                            <div className="font-medium">{row.user_name || 'Pengguna'}</div>
                                            <div className="text-xs text-muted-foreground">
                                                {row.user_email || '-'} · {row.user_role || '-'}
                                            </div>
                                        </td>
                                        <td className="py-3 pr-4">
                                            <Badge variant="secondary">
                                                {CATEGORY_LABELS[row.category] || row.category}
                                            </Badge>
                                        </td>
                                        <td className="py-3 pr-4">
                                            <div className="font-semibold">{row.title}</div>
                                            <div className="max-w-md text-xs text-muted-foreground">{row.body}</div>
                                            {row.target_route && (
                                                <div className="mt-1 text-[11px] text-primary">
                                                    Route: {row.target_route}
                                                </div>
                                            )}
                                        </td>
                                        <td className="py-3 pr-4">
                                            <Badge variant={row.is_read ? 'outline' : 'default'}>
                                                {row.is_read ? 'Dibaca' : 'Belum Dibaca'}
                                            </Badge>
                                        </td>
                                        <td className="py-3 pr-4 text-xs text-muted-foreground">
                                            {formatDate(row.created_at)}
                                        </td>
                                        <td className="py-3 text-right">
                                            <ConfirmActionDialog
                                                title="Hapus Notifikasi"
                                                description={`Hapus log notifikasi "${row.title}" untuk ${row.user_name || 'pengguna ini'}?`}
                                                actionLabel="Hapus"
                                                triggerLabel="Hapus"
                                                variant="destructive"
                                                onConfirm={() => handleDelete(row)}
                                            />
                                        </td>
                                    </tr>
                                ))}
                                {notifications.data.length === 0 && (
                                    <tr>
                                        <td colSpan={6} className="py-8 text-center text-muted-foreground">
                                            Belum ada riwayat notifikasi.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>

                        <div className="mt-4">
                            <Pagination links={notifications.links} />
                        </div>
                    </CardContent>
                </Card>

                <Dialog open={isOpen} onOpenChange={setIsOpen}>
                    <DialogContent className="max-w-lg">
                        <DialogHeader>
                            <DialogTitle>Kirim Broadcast Notifikasi</DialogTitle>
                            <DialogDescription>
                                Notifikasi akan langsung muncul secara realtime di aplikasi Flutter penerima.
                            </DialogDescription>
                        </DialogHeader>
                        <form onSubmit={handleBroadcast} className="space-y-4">
                            <div className="grid gap-3 sm:grid-cols-2">
                                <div className="space-y-1.5">
                                    <Label htmlFor="notif-target-mode">Target Penerima *</Label>
                                    <select
                                        id="notif-target-mode"
                                        value={targetMode}
                                        onChange={(e) => setTargetMode(e.target.value as 'all' | 'role' | 'user')}
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                    >
                                        <option value="all">Semua Pengguna Aktif</option>
                                        <option value="role">Berdasarkan Role</option>
                                        <option value="user">Pengguna Tertentu</option>
                                    </select>
                                </div>
                                <div className="space-y-1.5">
                                    <Label htmlFor="notif-category">Kategori *</Label>
                                    <select
                                        id="notif-category"
                                        value={category}
                                        onChange={(e) => setCategory(e.target.value as 'promo' | 'system' | 'transaction')}
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                    >
                                        <option value="promo">Promo &amp; Flash Sale</option>
                                        <option value="system">Sistem &amp; Pengumuman</option>
                                        <option value="transaction">Transaksi</option>
                                    </select>
                                </div>
                            </div>

                            {targetMode === 'role' && (
                                <div className="space-y-1.5">
                                    <Label htmlFor="notif-target-role">Pilih Role *</Label>
                                    <select
                                        id="notif-target-role"
                                        value={targetRole}
                                        onChange={(e) => setTargetRole(e.target.value)}
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                    >
                                        <option value="buyer">Pembeli (buyer)</option>
                                        <option value="seller">Penjual UMK (seller)</option>
                                        <option value="assistant">Asisten UMK (assistant)</option>
                                        <option value="ekspedisi">Mitra Ekspedisi (ekspedisi)</option>
                                        <option value="ojek">Driver Ojek (ojek)</option>
                                    </select>
                                </div>
                            )}

                            {targetMode === 'user' && (
                                <div className="space-y-1.5">
                                    <Label htmlFor="notif-target-user">Pilih Pengguna *</Label>
                                    <select
                                        id="notif-target-user"
                                        value={targetUserId}
                                        onChange={(e) => setTargetUserId(e.target.value)}
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                        required
                                    >
                                        {users.map((u) => (
                                            <option key={u.id} value={u.id}>
                                                {u.full_name || 'User'} ({u.role}) — {u.email || u.id}
                                            </option>
                                        ))}
                                    </select>
                                </div>
                            )}

                            <div className="space-y-1.5">
                                <Label htmlFor="notif-title">Judul Notifikasi *</Label>
                                <Input
                                    id="notif-title"
                                    value={title}
                                    onChange={(e) => setTitle(e.target.value)}
                                    placeholder="Contoh: Promo Spesial Akhir Bulan!"
                                    required
                                />
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="notif-body">Isi Pesan *</Label>
                                <textarea
                                    id="notif-body"
                                    value={body}
                                    onChange={(e) => setBody(e.target.value)}
                                    rows={3}
                                    className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                    placeholder="Tulis pesan notifikasi untuk pengguna..."
                                    required
                                />
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="notif-route">Deep-Link Route Tujuan (Opsional)</Label>
                                <select
                                    id="notif-route-preset"
                                    value={ROUTE_PRESETS.some((p) => p.value === targetRoute) ? targetRoute : ''}
                                    onChange={(e) => {
                                        if (e.target.value) {
setTargetRoute(e.target.value);
}
                                    }}
                                    className="mb-1.5 h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                >
                                    <option value="">-- Pilih preset route atau ketik manual --</option>
                                    {ROUTE_PRESETS.map((preset) => (
                                        <option key={preset.value} value={preset.value}>
                                            {preset.label}
                                        </option>
                                    ))}
                                </select>
                                <Input
                                    id="notif-route"
                                    value={targetRoute}
                                    onChange={(e) => setTargetRoute(e.target.value)}
                                    placeholder="/home"
                                />
                            </div>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                    Batal
                                </Button>
                                <Button type="submit" disabled={isSubmitting}>
                                    {isSubmitting ? 'Mengirim...' : 'Kirim Sekarang'}
                                </Button>
                            </DialogFooter>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>
        </>
    );
}
