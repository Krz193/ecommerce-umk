import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Plus, Search, Star } from 'lucide-react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
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
import type { Paginated } from '@/types';

type ProductOption = {
    id: string;
    name: string;
    store_id: string;
    store: {
        id: string;
        name: string;
    };
};

type ProductRecommendationRow = {
    id: string;
    product_id: string;
    priority: number;
    badge_text: string | null;
    is_active: boolean;
    created_at: string;
    updated_at: string;
    product: ProductOption;
};

type RecommendationsIndexProps = {
    recommendations: Paginated<ProductRecommendationRow>;
    filters: {
        search: string;
    };
    availableProducts?: ProductOption[];
};

export default function RecommendationsIndex({
    recommendations,
    filters,
    availableProducts = [],
}: RecommendationsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');

    // Form Modal state
    const [isOpen, setIsOpen] = useState(false);
    const [editingItem, setEditingItem] = useState<ProductRecommendationRow | null>(null);
    const [productId, setProductId] = useState('');
    const [priority, setPriority] = useState(0);
    const [badgeText, setBadgeText] = useState('');
    const [isActive, setIsActive] = useState(true);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/recommendations', { search }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingItem(null);
        setProductId(availableProducts.length > 0 ? availableProducts[0].id : '');
        setPriority(0);
        setBadgeText('');
        setIsActive(true);
        setIsOpen(true);
    }

    function openEditModal(item: ProductRecommendationRow) {
        setEditingItem(item);
        setProductId(item.product_id);
        setPriority(item.priority);
        setBadgeText(item.badge_text || '');
        setIsActive(item.is_active);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        if (editingItem) {
            router.patch(`/recommendations/${editingItem.id}`, {
                priority,
                badge_text: badgeText || undefined,
                is_active: isActive,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/recommendations', {
                product_id: productId,
                priority,
                badge_text: badgeText || undefined,
                is_active: isActive,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    return (
        <div className="flex-1 space-y-4 p-4 md:p-8 pt-6">
            <Head title="Rekomendasi Produk" />

            <div className="flex items-center justify-between space-y-2">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">Rekomendasi Produk</h2>
                    <p className="text-muted-foreground">
                        Kelola kurasi produk unggulan dan rekomendasi prioritas untuk ditampilkan ke pembeli.
                    </p>
                </div>
                <div className="flex items-center space-x-2">
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-2 h-4 w-4" />
                        Tambah Rekomendasi
                    </Button>
                </div>
            </div>

            <Card>
                <CardHeader>
                    <CardTitle>Daftar Rekomendasi</CardTitle>
                </CardHeader>
                <CardContent>
                    <form onSubmit={submitFilter} className="flex items-center space-x-2 mb-4">
                        <div className="relative flex-1 max-w-sm">
                            <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                            <Input
                                type="search"
                                placeholder="Cari nama produk atau toko..."
                                className="pl-8"
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                            />
                        </div>
                        <Button type="submit" variant="secondary">Cari</Button>
                    </form>

                    <div className="rounded-md border">
                        <div className="w-full overflow-auto">
                            <table className="w-full caption-bottom text-sm">
                                <thead className="[&_tr]:border-b">
                                    <tr className="border-b transition-colors hover:bg-muted/50 data-[state=selected]:bg-muted">
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Toko UMK</th>
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Produk</th>
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Prioritas</th>
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Badge</th>
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Status</th>
                                        <th className="h-12 px-4 text-left align-middle font-medium text-muted-foreground">Tgl Dibuat</th>
                                        <th className="h-12 px-4 text-right align-middle font-medium text-muted-foreground">Aksi</th>
                                    </tr>
                                </thead>
                                <tbody className="[&_tr:last-child]:border-0">
                                    {recommendations.data.map((item) => (
                                        <tr key={item.id} className="border-b transition-colors hover:bg-muted/50 data-[state=selected]:bg-muted">
                                            <td className="p-4 align-middle">
                                                <div className="font-medium">{item.product?.store?.name}</div>
                                            </td>
                                            <td className="p-4 align-middle">
                                                {item.product?.name}
                                            </td>
                                            <td className="p-4 align-middle font-mono font-medium">
                                                {item.priority}
                                            </td>
                                            <td className="p-4 align-middle">
                                                {item.badge_text ? (
                                                    <span className="inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold bg-amber-100 text-amber-800 border-amber-200">
                                                        <Star className="mr-1 h-3 w-3" />
                                                        {item.badge_text}
                                                    </span>
                                                ) : (
                                                    <span className="text-muted-foreground">-</span>
                                                )}
                                            </td>
                                            <td className="p-4 align-middle">
                                                <StatusBadge
                                                    status={item.is_active ? 'active' : 'draft'}
                                                />
                                            </td>
                                            <td className="p-4 align-middle">
                                                {formatDate(item.created_at)}
                                            </td>
                                            <td className="p-4 align-middle text-right space-x-2">
                                                <Button variant="outline" size="sm" onClick={() => openEditModal(item)}>
                                                    Edit
                                                </Button>
                                                <ConfirmActionDialog
                                                    title="Hapus Rekomendasi?"
                                                    description="Apakah Anda yakin ingin menghapus produk ini dari daftar rekomendasi? Ini tidak menghapus produk dari katalog, hanya mencabut status rekomendasinya."
                                                    onConfirm={() => router.delete(`/recommendations/${item.id}`)}
                                                    triggerLabel="Hapus"
                                                    actionLabel="Hapus"
                                                    variant="destructive"
                                                />
                                            </td>
                                        </tr>
                                    ))}
                                    {recommendations.data.length === 0 && (
                                        <tr>
                                            <td colSpan={7} className="p-4 text-center text-muted-foreground">
                                                Tidak ada rekomendasi produk ditemukan.
                                            </td>
                                        </tr>
                                    )}
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div className="mt-4">
                        <Pagination links={recommendations.links} />
                    </div>
                </CardContent>
            </Card>

            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[500px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingItem ? 'Edit Rekomendasi Produk' : 'Tambah Rekomendasi Produk'}</DialogTitle>
                            <DialogDescription>
                                {editingItem ? 'Perbarui pengaturan rekomendasi untuk produk ini.' : 'Pilih produk dari katalog untuk ditambahkan ke daftar unggulan.'}
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="product">Pilih Produk</Label>
                                {editingItem ? (
                                    <div className="p-2 border rounded bg-muted/50 text-sm">
                                        {editingItem.product?.name} ({editingItem.product?.store?.name})
                                    </div>
                                ) : (
                                    <select
                                        id="product"
                                        className="flex h-10 w-full items-center justify-between rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                                        value={productId}
                                        onChange={(e) => setProductId(e.target.value)}
                                        required
                                    >
                                        <option value="" disabled>Pilih Produk...</option>
                                        {availableProducts.map((p) => (
                                            <option key={p.id} value={p.id}>{p.name} - ({p.store?.name})</option>
                                        ))}
                                    </select>
                                )}
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="priority">Prioritas (Angka Lebih Besar = Lebih Di Atas)</Label>
                                <Input
                                    id="priority"
                                    type="number"
                                    min="0"
                                    value={priority}
                                    onChange={(e) => setPriority(parseInt(e.target.value) || 0)}
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="badge">Teks Badge (Opsional)</Label>
                                <Input
                                    id="badge"
                                    placeholder="Contoh: Pilihan Admin, Terlaris, Unggulan"
                                    value={badgeText}
                                    onChange={(e) => setBadgeText(e.target.value)}
                                />
                                <p className="text-xs text-muted-foreground">Teks pendek yang muncul sebagai label khusus pada produk.</p>
                            </div>

                            <div className="flex items-center space-x-2 pt-2">
                                <input
                                    type="checkbox"
                                    id="is_active"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                    className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
                                />
                                <Label htmlFor="is_active">Aktif (Tampilkan di Beranda Pembeli)</Label>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Batal
                            </Button>
                            <Button type="submit">Simpan</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </div>
    );
}
