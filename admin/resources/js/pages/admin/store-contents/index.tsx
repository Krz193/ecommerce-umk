import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Copy, ExternalLink, Megaphone, Plus, Search } from 'lucide-react';
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
import type { Paginated, StoreContentRow } from '@/types';

type OptionItem = {
    id: string;
    name: string;
    store_id?: string;
};

type StoreContentsIndexProps = {
    contents: Paginated<StoreContentRow>;
    filters: {
        search: string;
        type: string;
    };
    stores?: OptionItem[];
    products?: OptionItem[];
};

const FORMAT_LABELS: Record<string, string> = {
    image: 'Gambar / Foto',
    video: 'Video',
    short_video: 'Reels / Shorts',
    carousel: 'Carousel Slide',
    article: 'Artikel / Teks',
};

const PLATFORM_LABELS: Record<string, string> = {
    instagram: 'Instagram',
    tiktok: 'TikTok',
    youtube: 'YouTube',
    facebook: 'Facebook',
    whatsapp: 'WhatsApp',
    marketplace: 'Marketplace',
};

export default function StoreContentsIndex({
    contents,
    filters,
    stores = [],
    products = [],
}: StoreContentsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [type, setType] = useState(filters.type || '');

    // Form Modal state
    const [isOpen, setIsOpen] = useState(false);
    const [editingContent, setEditingContent] = useState<StoreContentRow | null>(null);
    const [storeId, setStoreId] = useState('');
    const [productId, setProductId] = useState('');
    const [title, setTitle] = useState('');
    const [contentType, setContentType] = useState<'banner' | 'promo' | 'storytelling' | 'social' | 'educational'>('promo');
    const [socialPlatform, setSocialPlatform] = useState('');
    const [mediaFormat, setMediaFormat] = useState<'image' | 'video' | 'short_video' | 'carousel' | 'article'>('image');
    const [externalUrl, setExternalUrl] = useState('');
    const [body, setBody] = useState('');
    const [isActive, setIsActive] = useState(true);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/store-contents', { search, type }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingContent(null);
        setStoreId(stores.length > 0 ? stores[0].id : '');
        setProductId('');
        setTitle('');
        setContentType('promo');
        setSocialPlatform('');
        setMediaFormat('image');
        setExternalUrl('');
        setBody('');
        setIsActive(true);
        setIsOpen(true);
    }

    function openEditModal(item: StoreContentRow) {
        setEditingContent(item);
        setStoreId(item.store_id);
        setProductId(item.product_id || '');
        setTitle(item.title);
        setContentType(item.content_type);
        setSocialPlatform(item.social_platform || '');
        setMediaFormat(item.media_format || 'image');
        setExternalUrl(item.external_url || '');
        setBody(item.body || '');
        setIsActive(item.is_active);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        const payload = {
            product_id: productId || undefined,
            title,
            content_type: contentType,
            social_platform: socialPlatform || undefined,
            media_format: mediaFormat,
            external_url: externalUrl || undefined,
            body: body || undefined,
            is_active: isActive,
        };

        if (editingContent) {
            router.patch(`/store-contents/${editingContent.id}`, payload, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/store-contents', {
                store_id: storeId,
                ...payload,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    function handleDelete(item: StoreContentRow) {
        router.delete(`/store-contents/${item.id}`);
    }

    const filteredProducts = storeId
        ? products.filter((p) => !p.store_id || p.store_id === storeId)
        : products;

    return (
        <>
            <Head title="Promosi & Konten UMK" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold flex items-center gap-2">
                            <Megaphone className="h-6 w-6 text-primary" /> Promosi & Konten UMK
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Kelola banner promosi, materi promo toko, bentuk media (video/gambar), dan konten sosial UMK.
                        </p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-1 h-4 w-4" /> Buat Konten Promosi
                    </Button>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <Input
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                placeholder="Cari judul promo, toko, atau produk"
                            />
                            <select
                                className="h-9 rounded-md border bg-background px-3 text-sm"
                                value={type}
                                onChange={(e) => setType(e.target.value)}
                            >
                                <option value="">Semua Tipe Konten</option>
                                <option value="banner">Banner Promosi</option>
                                <option value="promo">Promo Diskon / Penawaran</option>
                                <option value="storytelling">Storytelling UMK</option>
                                <option value="social">Konten Sosial</option>
                                <option value="educational">Materi Edukasi UMK</option>
                            </select>
                            <Button type="submit">
                                <Search className="mr-1 h-4 w-4" /> Filter
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardContent className="overflow-x-auto pt-6">
                        <table className="w-full min-w-[980px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Judul Konten</th>
                                    <th className="pb-3 font-medium">Toko UMK</th>
                                    <th className="pb-3 font-medium">Produk Terhubung</th>
                                    <th className="pb-3 font-medium">Tipe & Bentuk</th>
                                    <th className="pb-3 font-medium">Platform & Link</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Dibuat</th>
                                    <th className="pb-3 text-right font-medium">Aksi</th>
                                </tr>
                            </thead>
                            <tbody>
                                {contents.data.length === 0 ? (
                                    <tr>
                                        <td colSpan={8} className="py-6 text-center text-muted-foreground">
                                            Belum ada konten promosi UMK.
                                        </td>
                                    </tr>
                                ) : (
                                    contents.data.map((item) => (
                                        <tr key={item.id} className="border-b last:border-0">
                                            <td className="py-3 font-medium">
                                                <div>{item.title}</div>
                                                {item.body && (
                                                    <div className="max-w-xs truncate text-xs text-muted-foreground">
                                                        {item.body}
                                                    </div>
                                                )}
                                            </td>
                                            <td className="py-3">{item.store_name}</td>
                                            <td className="py-3">{item.product_name || '-'}</td>
                                            <td className="py-3">
                                                <div className="flex flex-col gap-1 items-start">
                                                    <span className="rounded bg-accent px-2 py-0.5 text-xs font-semibold capitalize">
                                                        {item.content_type}
                                                    </span>
                                                    <span className="rounded bg-blue-50 text-blue-700 px-2 py-0.5 text-xs font-medium">
                                                        {FORMAT_LABELS[item.media_format || 'image'] || item.media_format}
                                                    </span>
                                                </div>
                                            </td>
                                            <td className="py-3">
                                                <div className="flex flex-col gap-1 items-start">
                                                    <span className="text-xs font-medium">
                                                        {item.social_platform ? (PLATFORM_LABELS[item.social_platform] || item.social_platform) : 'Internal App'}
                                                    </span>
                                                    {item.external_url && (
                                                        <div className="flex items-center gap-1">
                                                            <a
                                                                href={item.external_url}
                                                                target="_blank"
                                                                rel="noreferrer"
                                                                className="inline-flex items-center gap-1 rounded bg-primary/10 px-2 py-0.5 text-xs text-primary hover:underline"
                                                            >
                                                                <ExternalLink className="h-3 w-3" /> Buka
                                                            </a>
                                                            <button
                                                                type="button"
                                                                onClick={() => navigator.clipboard?.writeText(item.external_url || '')}
                                                                className="inline-flex items-center gap-1 rounded border px-2 py-0.5 text-xs text-muted-foreground hover:bg-accent"
                                                            >
                                                                <Copy className="h-3 w-3" /> Salin
                                                            </button>
                                                        </div>
                                                    )}
                                                </div>
                                            </td>
                                            <td className="py-3">
                                                <StatusBadge status={item.is_active ? 'active' : 'inactive'} />
                                            </td>
                                            <td className="py-3">{formatDate(item.created_at)}</td>
                                            <td className="py-3 text-right">
                                                <div className="flex justify-end gap-2">
                                                    <Button variant="outline" size="sm" onClick={() => openEditModal(item)}>
                                                        Edit
                                                    </Button>
                                                    <ConfirmActionDialog
                                                        title={`Hapus "${item.title}"?`}
                                                        description="Apakah Anda yakin ingin menghapus konten promosi ini?"
                                                        actionLabel="Hapus Konten"
                                                        triggerLabel="Hapus"
                                                        variant="destructive"
                                                        onConfirm={() => handleDelete(item)}
                                                    />
                                                </div>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>

                        <Pagination links={contents.links} />
                    </CardContent>
                </Card>
            </div>

            {/* Create / Edit Dialog */}
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[540px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingContent ? 'Edit Konten Promosi' : 'Buat Konten Promosi UMK'}</DialogTitle>
                            <DialogDescription>
                                {editingContent
                                    ? 'Perbarui rincian banner/promo, bentuk media, dan platform UMK.'
                                    : 'Tambahkan materi promosi, konten media sosial, atau edukasi UMK baru.'}
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            {!editingContent && (
                                <div className="grid gap-2">
                                    <Label htmlFor="content_store">Toko UMK Target *</Label>
                                    <select
                                        id="content_store"
                                        className="h-9 rounded-md border bg-background px-3 text-sm"
                                        value={storeId}
                                        onChange={(e) => {
                                            setStoreId(e.target.value);
                                            setProductId('');
                                        }}
                                        required
                                    >
                                        {stores.map((s) => (
                                            <option key={s.id} value={s.id}>{s.name}</option>
                                        ))}
                                    </select>
                                </div>
                            )}

                            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                                <div className="grid gap-2">
                                    <Label htmlFor="content_type">Tipe Konten *</Label>
                                    <select
                                        id="content_type"
                                        className="h-9 rounded-md border bg-background px-3 text-sm"
                                        value={contentType}
                                        onChange={(e) => setContentType(e.target.value as any)}
                                    >
                                        <option value="promo">Promo Diskon / Penawaran</option>
                                        <option value="banner">Banner Promosi</option>
                                        <option value="storytelling">Storytelling UMK</option>
                                        <option value="social">Konten Sosial Media</option>
                                        <option value="educational">Materi Edukasi UMK</option>
                                    </select>
                                </div>

                                <div className="grid gap-2">
                                    <Label htmlFor="media_format">Bentuk Konten (Format Media) *</Label>
                                    <select
                                        id="media_format"
                                        className="h-9 rounded-md border bg-background px-3 text-sm"
                                        value={mediaFormat}
                                        onChange={(e) => setMediaFormat(e.target.value as any)}
                                    >
                                        <option value="image">Gambar / Foto</option>
                                        <option value="video">Video</option>
                                        <option value="short_video">Reels / TikTok / Shorts</option>
                                        <option value="carousel">Carousel Slide</option>
                                        <option value="article">Artikel / Teks</option>
                                    </select>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                                <div className="grid gap-2">
                                    <Label htmlFor="social_platform">Platform Media Sosial</Label>
                                    <select
                                        id="social_platform"
                                        className="h-9 rounded-md border bg-background px-3 text-sm"
                                        value={socialPlatform}
                                        onChange={(e) => setSocialPlatform(e.target.value)}
                                    >
                                        <option value="">Internal Aplikasi Saja</option>
                                        <option value="instagram">Instagram</option>
                                        <option value="tiktok">TikTok</option>
                                        <option value="youtube">YouTube</option>
                                        <option value="facebook">Facebook</option>
                                        <option value="whatsapp">WhatsApp</option>
                                        <option value="marketplace">Marketplace</option>
                                    </select>
                                </div>

                                <div className="grid gap-2">
                                    <Label htmlFor="external_url">URL Eksternal (Medsos / Video)</Label>
                                    <Input
                                        id="external_url"
                                        value={externalUrl}
                                        onChange={(e) => setExternalUrl(e.target.value)}
                                        placeholder="https://instagram.com/p/..."
                                    />
                                </div>
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="content_title">Judul Promosi *</Label>
                                <Input
                                    id="content_title"
                                    value={title}
                                    onChange={(e) => setTitle(e.target.value)}
                                    placeholder="e.g. Diskon Spesial UMK 20%"
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="content_product">Produk Terhubung (Opsional)</Label>
                                <select
                                    id="content_product"
                                    className="h-9 rounded-md border bg-background px-3 text-sm"
                                    value={productId}
                                    onChange={(e) => setProductId(e.target.value)}
                                >
                                    <option value="">-- Tidak Terhubung ke Produk Spesifik --</option>
                                    {filteredProducts.map((p) => (
                                        <option key={p.id} value={p.id}>{p.name}</option>
                                    ))}
                                </select>
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="content_body">Deskripsi / Detail Promo</Label>
                                <Input
                                    id="content_body"
                                    value={body}
                                    onChange={(e) => setBody(e.target.value)}
                                    placeholder="Syarat & ketentuan promo / uraian materi"
                                />
                            </div>

                            <div className="flex items-center gap-2 pt-2">
                                <input
                                    type="checkbox"
                                    id="content_active"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                    className="h-4 w-4 rounded border-gray-300"
                                />
                                <Label htmlFor="content_active" className="cursor-pointer">
                                    Aktif / Tampilkan di Aplikasi
                                </Label>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Batal
                            </Button>
                            <Button type="submit">{editingContent ? 'Simpan Perubahan' : 'Buat Konten'}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
