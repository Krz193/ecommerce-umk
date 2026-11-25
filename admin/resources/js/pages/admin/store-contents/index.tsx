import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Copy, ExternalLink, Megaphone, Search } from 'lucide-react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { Pagination } from '@/components/admin/pagination';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { formatDate } from '@/lib/format';
import type { Paginated, StoreContentRow } from '@/types';

type StoreContentsIndexProps = {
    contents: Paginated<StoreContentRow>;
    filters: {
        search: string;
        type: string;
        platform: string;
    };
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

function toSafeHttpUrl(rawUrl: string): string {
    const trimmed = rawUrl.trim();
    return /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
}

export default function StoreContentsIndex({
    contents,
    filters,
}: StoreContentsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [type, setType] = useState(filters.type || '');
    const [platform, setPlatform] = useState(filters.platform || '');

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get(
            '/store-contents',
            { search, type, platform },
            { preserveState: true, replace: true },
        );
    }

    function handleDelete(item: StoreContentRow) {
        router.delete(`/store-contents/${item.id}`);
    }

    return (
        <>
            <Head title="Monitoring Konten & Engagement UMK" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-semibold">
                        <Megaphone className="h-6 w-6 text-primary" /> Monitoring Konten & Engagement UMK
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Pantau link bukti upload konten eksternal dan performa engagement yang dicatat oleh Asisten UMK (Read-Only + Moderasi Hapus).
                    </p>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filter Konten</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <Input
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                placeholder="Cari judul, toko UMK, produk, atau nama asisten"
                            />
                            <select
                                className="h-9 rounded-md border bg-background px-3 text-sm"
                                value={platform}
                                onChange={(e) => setPlatform(e.target.value)}
                            >
                                <option value="">Semua Platform</option>
                                <option value="instagram">Instagram</option>
                                <option value="tiktok">TikTok</option>
                                <option value="youtube">YouTube</option>
                                <option value="facebook">Facebook</option>
                                <option value="whatsapp">WhatsApp</option>
                                <option value="marketplace">Marketplace</option>
                            </select>
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
                        <table className="w-full min-w-[1100px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Judul & Catatan</th>
                                    <th className="pb-3 font-medium">Toko UMK & Asisten</th>
                                    <th className="pb-3 font-medium">Produk Terhubung</th>
                                    <th className="pb-3 font-medium">Tipe & Format</th>
                                    <th className="pb-3 font-medium">Platform & Bukti Link</th>
                                    <th className="pb-3 font-medium">Metrik Engagement</th>
                                    <th className="pb-3 font-medium">Tanggal Upload</th>
                                    <th className="pb-3 text-right font-medium">Moderasi</th>
                                </tr>
                            </thead>
                            <tbody>
                                {contents.data.length === 0 ? (
                                    <tr>
                                        <td colSpan={8} className="py-6 text-center text-muted-foreground">
                                            Belum ada konten eksternal yang dicatat oleh Asisten UMK.
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
                                            <td className="py-3">
                                                <div className="font-medium">{item.store_name}</div>
                                                <div className="text-xs text-muted-foreground">
                                                    Asisten: {item.creator_name || 'Asisten UMK'}
                                                </div>
                                            </td>
                                            <td className="py-3">{item.product_name || '-'}</td>
                                            <td className="py-3">
                                                <div className="flex flex-col items-start gap-1">
                                                    <span className="rounded bg-accent px-2 py-0.5 text-xs font-semibold capitalize">
                                                        {item.content_type}
                                                    </span>
                                                    <span className="rounded bg-blue-50 px-2 py-0.5 text-xs font-medium text-blue-700">
                                                        {FORMAT_LABELS[item.media_format || 'image'] || item.media_format}
                                                    </span>
                                                </div>
                                            </td>
                                            <td className="py-3">
                                                <div className="flex flex-col items-start gap-1">
                                                    <span className="text-xs font-semibold">
                                                        {item.social_platform
                                                            ? PLATFORM_LABELS[item.social_platform] || item.social_platform
                                                            : '-'}
                                                    </span>
                                                    {item.external_url && (
                                                        <div className="flex items-center gap-1">
                                                            <a
                                                                href={toSafeHttpUrl(item.external_url)}
                                                                target="_blank"
                                                                rel="noopener noreferrer"
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
                                                <div className="grid grid-cols-2 gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
                                                    <span>Reach: <strong className="text-foreground">{item.reach_count ?? 0}</strong></span>
                                                    <span>Likes: <strong className="text-foreground">{item.likes_count ?? 0}</strong></span>
                                                    <span>Komen: <strong className="text-foreground">{item.comments_count ?? 0}</strong></span>
                                                    <span>Share: <strong className="text-foreground">{item.shares_count ?? 0}</strong></span>
                                                    <span className="col-span-2">Leads: <strong className="text-foreground">{item.inquiries_count ?? 0}</strong></span>
                                                </div>
                                            </td>
                                            <td className="py-3">{formatDate(item.created_at)}</td>
                                            <td className="py-3 text-right">
                                                <ConfirmActionDialog
                                                    title={`Hapus "${item.title}"?`}
                                                    description="Apakah Anda yakin ingin menghapus konten ini dari monitoring?"
                                                    actionLabel="Hapus Konten"
                                                    triggerLabel="Hapus"
                                                    variant="destructive"
                                                    onConfirm={() => handleDelete(item)}
                                                />
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
        </>
    );
}
