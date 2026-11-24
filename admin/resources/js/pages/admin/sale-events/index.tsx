import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { CalendarClock, Plus, Search, Zap } from 'lucide-react';
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
import type { Paginated, SaleEventRow } from '@/types';

type StoreOption = {
    id: string;
    name: string;
};

type SaleEventsIndexProps = {
    events: Paginated<SaleEventRow>;
    stats: {
        total: number;
        ongoing: number;
        upcoming: number;
        ended: number;
    };
    filters: {
        search: string;
        state: string;
    };
    stores: StoreOption[];
};

function toLocalInputValue(iso?: string | null): string {
    const date = iso ? new Date(iso) : new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function getEventState(event: SaleEventRow): {
    label: string;
    variant: 'default' | 'secondary' | 'destructive' | 'outline';
} {
    if (!event.is_active) {
        return { label: 'Nonaktif', variant: 'outline' };
    }
    const now = Date.now();
    const start = new Date(event.start_time).getTime();
    const end = new Date(event.end_time).getTime();

    if (now < start) {
        return { label: 'Akan Datang', variant: 'secondary' };
    }
    if (now > end) {
        return { label: 'Berakhir', variant: 'destructive' };
    }
    return { label: 'Sedang Berlangsung', variant: 'default' };
}

export default function SaleEventsIndex({
    events,
    stats,
    filters,
    stores,
}: SaleEventsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [stateFilter, setStateFilter] = useState(filters.state || '');

    const [isOpen, setIsOpen] = useState(false);
    const [editingEvent, setEditingEvent] = useState<SaleEventRow | null>(null);
    const [title, setTitle] = useState('');
    const [storeId, setStoreId] = useState('');
    const [description, setDescription] = useState('');
    const [bannerUrl, setBannerUrl] = useState('');
    const [startTime, setStartTime] = useState('');
    const [endTime, setEndTime] = useState('');
    const [isActive, setIsActive] = useState(true);
    const [isSubmitting, setIsSubmitting] = useState(false);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get(
            '/sale-events',
            { search, state: stateFilter },
            { preserveState: true, replace: true },
        );
    }

    function openCreateModal() {
        const now = new Date();
        const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
        setEditingEvent(null);
        setTitle('');
        setStoreId('');
        setDescription('');
        setBannerUrl('');
        setStartTime(toLocalInputValue(now.toISOString()));
        setEndTime(toLocalInputValue(tomorrow.toISOString()));
        setIsActive(true);
        setIsOpen(true);
    }

    function openEditModal(item: SaleEventRow) {
        setEditingEvent(item);
        setTitle(item.title);
        setStoreId(item.store_id || '');
        setDescription(item.description || '');
        setBannerUrl(item.banner_url || '');
        setStartTime(toLocalInputValue(item.start_time));
        setEndTime(toLocalInputValue(item.end_time));
        setIsActive(item.is_active);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        setIsSubmitting(true);

        const payload = {
            title,
            store_id: storeId || null,
            description: description || null,
            banner_url: bannerUrl || null,
            start_time: new Date(startTime).toISOString(),
            end_time: new Date(endTime).toISOString(),
            is_active: isActive,
        };

        const options = {
            preserveScroll: true,
            onSuccess: () => {
                setIsOpen(false);
                setIsSubmitting(false);
            },
            onError: () => setIsSubmitting(false),
        };

        if (editingEvent) {
            router.patch(`/sale-events/${editingEvent.id}`, payload, options);
        } else {
            router.post('/sale-events', payload, options);
        }
    }

    function handleDelete(item: SaleEventRow) {
        router.delete(`/sale-events/${item.id}`, { preserveScroll: true });
    }

    return (
        <>
            <Head title="Flash Sale & Sale Event" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-center">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-semibold">
                            <Zap className="h-6 w-6 text-orange-500" />
                            Flash Sale &amp; Sale Event
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Kelola event diskon berbatas waktu dan kuota untuk platform maupun toko UMK.
                        </p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-2 h-4 w-4" />
                        Buat Sale Event
                    </Button>
                </div>

                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Total Event</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">{stats.total}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Sedang Berlangsung</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold text-green-600">{stats.ongoing}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Akan Datang</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold text-amber-600">{stats.upcoming}</CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm font-medium text-muted-foreground">Berakhir</CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold text-muted-foreground">{stats.ended}</CardContent>
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
                                    placeholder="Cari judul event, deskripsi, atau nama toko..."
                                    className="pl-9"
                                />
                            </div>
                            <select
                                value={stateFilter}
                                onChange={(e) => setStateFilter(e.target.value)}
                                className="h-9 rounded-md border border-input bg-background px-3 text-sm"
                            >
                                <option value="">Semua Status</option>
                                <option value="ongoing">Sedang Berlangsung</option>
                                <option value="upcoming">Akan Datang</option>
                                <option value="ended">Berakhir</option>
                                <option value="inactive">Nonaktif</option>
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
                                    <th className="pb-3 pr-4">Event</th>
                                    <th className="pb-3 pr-4">Lingkup</th>
                                    <th className="pb-3 pr-4">Periode</th>
                                    <th className="pb-3 pr-4">Produk / Terjual</th>
                                    <th className="pb-3 pr-4">Status</th>
                                    <th className="pb-3 text-right">Aksi</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y">
                                {events.data.map((eventItem) => {
                                    const state = getEventState(eventItem);
                                    return (
                                        <tr key={eventItem.id} className="align-top">
                                            <td className="py-3 pr-4">
                                                <Link
                                                    href={`/sale-events/${eventItem.id}`}
                                                    className="font-semibold text-primary hover:underline"
                                                >
                                                    {eventItem.title}
                                                </Link>
                                                {eventItem.description && (
                                                    <p className="mt-0.5 line-clamp-1 max-w-md text-xs text-muted-foreground">
                                                        {eventItem.description}
                                                    </p>
                                                )}
                                            </td>
                                            <td className="py-3 pr-4">
                                                <Badge variant={eventItem.store_id ? 'outline' : 'secondary'}>
                                                    {eventItem.store_name || 'Platform (Semua Toko)'}
                                                </Badge>
                                            </td>
                                            <td className="py-3 pr-4 text-xs">
                                                <div className="flex items-center gap-1 font-medium">
                                                    <CalendarClock className="h-3.5 w-3.5 text-muted-foreground" />
                                                    <span>{formatDate(eventItem.start_time)}</span>
                                                </div>
                                                <div className="text-muted-foreground">
                                                    s/d {formatDate(eventItem.end_time)}
                                                </div>
                                            </td>
                                            <td className="py-3 pr-4 text-xs">
                                                <div className="font-medium">{eventItem.total_items ?? 0} Produk</div>
                                                <div className="text-muted-foreground">{eventItem.total_sold ?? 0} Terjual</div>
                                            </td>
                                            <td className="py-3 pr-4">
                                                <Badge variant={state.variant}>{state.label}</Badge>
                                            </td>
                                            <td className="py-3 text-right">
                                                <div className="flex justify-end gap-2">
                                                    <Button asChild size="sm" variant="default">
                                                        <Link href={`/sale-events/${eventItem.id}`}>Kelola Produk</Link>
                                                    </Button>
                                                    <Button
                                                        size="sm"
                                                        variant="outline"
                                                        onClick={() => openEditModal(eventItem)}
                                                    >
                                                        Edit
                                                    </Button>
                                                    <ConfirmActionDialog
                                                        title="Hapus Sale Event"
                                                        description={`Hapus event "${eventItem.title}" beserta seluruh daftar produk diskon di dalamnya?`}
                                                        actionLabel="Hapus"
                                                        triggerLabel="Hapus"
                                                        variant="destructive"
                                                        onConfirm={() => handleDelete(eventItem)}
                                                    />
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                })}
                                {events.data.length === 0 && (
                                    <tr>
                                        <td colSpan={6} className="py-8 text-center text-muted-foreground">
                                            Belum ada Sale Event yang dibuat.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>

                        <div className="mt-4">
                            <Pagination links={events.links} />
                        </div>
                    </CardContent>
                </Card>

                <Dialog open={isOpen} onOpenChange={setIsOpen}>
                    <DialogContent className="max-w-lg">
                        <DialogHeader>
                            <DialogTitle>{editingEvent ? 'Edit Sale Event' : 'Buat Flash Sale Event Baru'}</DialogTitle>
                            <DialogDescription>
                                Atur jadwal, judul, dan lingkup event Flash Sale. Harga produk tetap aman tanpa menimpa harga normal.
                            </DialogDescription>
                        </DialogHeader>
                        <form onSubmit={handleSave} className="space-y-4">
                            <div className="space-y-1.5">
                                <Label htmlFor="event-title">Judul Event *</Label>
                                <Input
                                    id="event-title"
                                    value={title}
                                    onChange={(e) => setTitle(e.target.value)}
                                    placeholder="Contoh: Flash Sale Gajian UMK 11.11"
                                    required
                                />
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="event-store">Lingkup Toko (Opsional)</Label>
                                <select
                                    id="event-store"
                                    value={storeId}
                                    onChange={(e) => setStoreId(e.target.value)}
                                    className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                >
                                    <option value="">Event Platform (Semua Toko UMK boleh ikut)</option>
                                    {stores.map((store) => (
                                        <option key={store.id} value={store.id}>
                                            Khusus Toko: {store.name}
                                        </option>
                                    ))}
                                </select>
                            </div>

                            <div className="grid gap-3 sm:grid-cols-2">
                                <div className="space-y-1.5">
                                    <Label htmlFor="event-start">Waktu Mulai *</Label>
                                    <Input
                                        id="event-start"
                                        type="datetime-local"
                                        value={startTime}
                                        onChange={(e) => setStartTime(e.target.value)}
                                        required
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <Label htmlFor="event-end">Waktu Berakhir *</Label>
                                    <Input
                                        id="event-end"
                                        type="datetime-local"
                                        value={endTime}
                                        onChange={(e) => setEndTime(e.target.value)}
                                        required
                                    />
                                </div>
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="event-banner">URL Banner (Opsional)</Label>
                                <Input
                                    id="event-banner"
                                    type="url"
                                    value={bannerUrl}
                                    onChange={(e) => setBannerUrl(e.target.value)}
                                    placeholder="https://..."
                                />
                            </div>

                            <div className="space-y-1.5">
                                <Label htmlFor="event-desc">Deskripsi Promo (Opsional)</Label>
                                <textarea
                                    id="event-desc"
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                    rows={3}
                                    className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                    placeholder="Penjelasan singkat promo Flash Sale ini..."
                                />
                            </div>

                            <label className="flex items-center gap-2 text-sm font-medium">
                                <input
                                    type="checkbox"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                />
                                Aktifkan event ini
                            </label>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                    Batal
                                </Button>
                                <Button type="submit" disabled={isSubmitting}>
                                    {isSubmitting ? 'Menyimpan...' : 'Simpan Event'}
                                </Button>
                            </DialogFooter>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>
        </>
    );
}
