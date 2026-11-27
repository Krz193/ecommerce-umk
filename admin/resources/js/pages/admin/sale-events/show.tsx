import { Head, Link, router } from '@inertiajs/react';
import { ArrowLeft, CalendarClock, Plus, Zap } from 'lucide-react';
import type { FormEvent} from 'react';
import { useMemo, useState } from 'react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
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
import { formatCurrency, formatDate } from '@/lib/format';
import type { SaleEventItemRow, SaleEventRow } from '@/types';

type ProductOption = {
    id: string;
    name: string;
    price: string | number;
    stock: number;
    store_id: string;
    status: string;
    store_name: string;
};

type SaleEventShowProps = {
    event: SaleEventRow;
    items: SaleEventItemRow[];
    products: ProductOption[];
};

function computePreviewSalePrice(
    basePrice: number,
    discountType: 'percentage' | 'nominal' | 'fixed_price',
    discountValue: number,
): number {
    if (!Number.isFinite(discountValue) || discountValue <= 0) {
        return basePrice;
    }

    if (discountType === 'percentage') {
        return Math.max(0, Math.round(basePrice * (1 - Math.min(100, discountValue) / 100)));
    }

    if (discountType === 'nominal') {
        return Math.max(0, Math.round(basePrice - discountValue));
    }

    return Math.max(0, Math.min(basePrice, Math.round(discountValue)));
}

export default function SaleEventShow({ event, items, products }: SaleEventShowProps) {
    const [isOpen, setIsOpen] = useState(false);
    const [editingItem, setEditingItem] = useState<SaleEventItemRow | null>(null);
    const [productId, setProductId] = useState(products[0]?.id || '');
    const [discountType, setDiscountType] = useState<'percentage' | 'nominal' | 'fixed_price'>('percentage');
    const [discountValue, setDiscountValue] = useState('20');
    const [saleQuota, setSaleQuota] = useState('');
    const [maxQtyPerUser, setMaxQtyPerUser] = useState('');
    const [isActive, setIsActive] = useState(true);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const selectedProduct = useMemo(() => {
        if (editingItem) {
            return {
                id: editingItem.product_id,
                name: editingItem.product_name,
                price: editingItem.regular_price,
                stock: editingItem.product_stock,
                store_name: editingItem.store_name,
            };
        }

        return products.find((p) => p.id === productId);
    }, [editingItem, productId, products]);

    const previewSalePrice = useMemo(() => {
        const base = Number(selectedProduct?.price ?? 0);
        const val = Number(discountValue);

        return computePreviewSalePrice(base, discountType, val);
    }, [selectedProduct, discountType, discountValue]);

    function openAddModal() {
        setEditingItem(null);
        setProductId(products[0]?.id || '');
        setDiscountType('percentage');
        setDiscountValue('20');
        setSaleQuota('');
        setMaxQtyPerUser('2');
        setIsActive(true);
        setIsOpen(true);
    }

    function openEditModal(item: SaleEventItemRow) {
        setEditingItem(item);
        setProductId(item.product_id);
        setDiscountType(item.discount_type);
        setDiscountValue(String(item.discount_value));
        setSaleQuota(item.sale_quota != null ? String(item.sale_quota) : '');
        setMaxQtyPerUser(item.max_qty_per_user != null ? String(item.max_qty_per_user) : '');
        setIsActive(item.is_active);
        setIsOpen(true);
    }

    function handleSaveItem(formEvent: FormEvent<HTMLFormElement>) {
        formEvent.preventDefault();
        setIsSubmitting(true);

        const payload = {
            product_id: productId,
            discount_type: discountType,
            discount_value: Number(discountValue),
            sale_quota: saleQuota.trim() ? Number(saleQuota) : null,
            max_qty_per_user: maxQtyPerUser.trim() ? Number(maxQtyPerUser) : null,
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

        if (editingItem) {
            router.patch(`/sale-events/${event.id}/items/${editingItem.id}`, payload, options);
        } else {
            router.post(`/sale-events/${event.id}/items`, payload, options);
        }
    }

    function handleRemoveItem(item: SaleEventItemRow) {
        router.delete(`/sale-events/${event.id}/items/${item.id}`, {
            preserveScroll: true,
        });
    }

    return (
        <>
            <Head title={`Flash Sale: ${event.title}`} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <Button asChild variant="outline" size="sm" className="mb-3">
                            <Link href="/sale-events">
                                <ArrowLeft className="mr-1.5 h-4 w-4" />
                                Kembali ke Daftar Event
                            </Link>
                        </Button>
                        <div className="flex flex-wrap items-center gap-2">
                            <h1 className="flex items-center gap-2 text-2xl font-semibold">
                                <Zap className="h-6 w-6 text-orange-500" />
                                {event.title}
                            </h1>
                            <Badge variant={event.is_active ? 'default' : 'outline'}>
                                {event.is_active ? 'Aktif' : 'Nonaktif'}
                            </Badge>
                            <Badge variant="secondary">
                                {event.store_name || 'Platform (Semua Toko)'}
                            </Badge>
                        </div>
                        <div className="mt-1 flex items-center gap-1.5 text-sm text-muted-foreground">
                            <CalendarClock className="h-4 w-4" />
                            <span>
                                {formatDate(event.start_time)} s/d {formatDate(event.end_time)}
                            </span>
                        </div>
                        {event.description && (
                            <p className="mt-2 max-w-2xl text-sm text-muted-foreground">{event.description}</p>
                        )}
                    </div>
                    <Button onClick={openAddModal} disabled={products.length === 0}>
                        <Plus className="mr-2 h-4 w-4" />
                        Tambah Produk Sale
                    </Button>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Daftar Produk dalam Event ({items.length})</CardTitle>
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead>
                                <tr className="border-b text-muted-foreground">
                                    <th className="pb-3 pr-4">Produk</th>
                                    <th className="pb-3 pr-4">Toko UMK</th>
                                    <th className="pb-3 pr-4">Harga Normal</th>
                                    <th className="pb-3 pr-4">Diskon</th>
                                    <th className="pb-3 pr-4">Harga Flash Sale</th>
                                    <th className="pb-3 pr-4">Kuota &amp; Terjual</th>
                                    <th className="pb-3 pr-4">Batas / Pembeli</th>
                                    <th className="pb-3 pr-4">Status</th>
                                    <th className="pb-3 text-right">Aksi</th>
                                </tr>
                            </thead>
                            <tbody className="divide-y">
                                {items.map((item) => {
                                    const quotaLabel =
                                        item.sale_quota != null
                                            ? `${item.sold_count} / ${item.sale_quota}`
                                            : `${item.sold_count} (Ikut Stok: ${item.product_stock})`;

                                    return (
                                        <tr key={item.id}>
                                            <td className="py-3 pr-4 font-medium">{item.product_name}</td>
                                            <td className="py-3 pr-4 text-muted-foreground">{item.store_name}</td>
                                            <td className="py-3 pr-4 line-through text-muted-foreground">
                                                {formatCurrency(item.regular_price)}
                                            </td>
                                            <td className="py-3 pr-4">
                                                <Badge variant="secondary">
                                                    {item.discount_type === 'percentage'
                                                        ? `${Number(item.discount_value)}%`
                                                        : item.discount_type === 'nominal'
                                                          ? `-${formatCurrency(item.discount_value)}`
                                                          : `Set ${formatCurrency(item.discount_value)}`}
                                                </Badge>
                                            </td>
                                            <td className="py-3 pr-4 font-bold text-orange-600">
                                                {formatCurrency(item.sale_price)}
                                            </td>
                                            <td className="py-3 pr-4 text-xs">{quotaLabel}</td>
                                            <td className="py-3 pr-4 text-xs">
                                                {item.max_qty_per_user != null ? `Maks ${item.max_qty_per_user} pcs` : 'Tanpa batas'}
                                            </td>
                                            <td className="py-3 pr-4">
                                                <Badge variant={item.is_active ? 'default' : 'outline'}>
                                                    {item.is_active ? 'Aktif' : 'Nonaktif'}
                                                </Badge>
                                            </td>
                                            <td className="py-3 text-right">
                                                <div className="flex justify-end gap-2">
                                                    <Button size="sm" variant="outline" onClick={() => openEditModal(item)}>
                                                        Edit
                                                    </Button>
                                                    <ConfirmActionDialog
                                                        title="Hapus Produk dari Flash Sale"
                                                        description={`Keluarkan "${item.product_name}" dari event "${event.title}"?`}
                                                        actionLabel="Hapus"
                                                        triggerLabel="Hapus"
                                                        variant="destructive"
                                                        onConfirm={() => handleRemoveItem(item)}
                                                    />
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                })}
                                {items.length === 0 && (
                                    <tr>
                                        <td colSpan={9} className="py-8 text-center text-muted-foreground">
                                            Belum ada produk pada event ini. Klik &ldquo;Tambah Produk Sale&rdquo; untuk memulai.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                <Dialog open={isOpen} onOpenChange={setIsOpen}>
                    <DialogContent className="max-w-lg">
                        <DialogHeader>
                            <DialogTitle>
                                {editingItem ? `Edit Diskon: ${editingItem.product_name}` : 'Tambah Produk ke Flash Sale'}
                            </DialogTitle>
                            <DialogDescription>
                                Harga Flash Sale dihitung otomatis di server berdasarkan harga produk saat ini.
                            </DialogDescription>
                        </DialogHeader>
                        <form onSubmit={handleSaveItem} className="space-y-4">
                            {!editingItem && (
                                <div className="space-y-1.5">
                                    <Label htmlFor="item-product">Pilih Produk *</Label>
                                    <select
                                        id="item-product"
                                        value={productId}
                                        onChange={(e) => setProductId(e.target.value)}
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                        required
                                    >
                                        {products.map((prod) => (
                                            <option key={prod.id} value={prod.id}>
                                                {prod.name} — {prod.store_name} ({formatCurrency(prod.price)} | Stok: {prod.stock})
                                            </option>
                                        ))}
                                    </select>
                                </div>
                            )}

                            <div className="grid gap-3 sm:grid-cols-2">
                                <div className="space-y-1.5">
                                    <Label htmlFor="item-discount-type">Tipe Diskon *</Label>
                                    <select
                                        id="item-discount-type"
                                        value={discountType}
                                        onChange={(e) =>
                                            setDiscountType(e.target.value as 'percentage' | 'nominal' | 'fixed_price')
                                        }
                                        className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm"
                                    >
                                        <option value="percentage">Persentase (%)</option>
                                        <option value="nominal">Potongan Nominal (Rp)</option>
                                        <option value="fixed_price">Harga Spesial Tetap (Rp)</option>
                                    </select>
                                </div>
                                <div className="space-y-1.5">
                                    <Label htmlFor="item-discount-value">
                                        {discountType === 'percentage'
                                            ? 'Persen Diskon (%) *'
                                            : discountType === 'nominal'
                                              ? 'Nominal Potongan (Rp) *'
                                              : 'Harga Jual Flash Sale (Rp) *'}
                                    </Label>
                                    <Input
                                        id="item-discount-value"
                                        type="number"
                                        min="1"
                                        max={discountType === 'percentage' ? 99 : undefined}
                                        value={discountValue}
                                        onChange={(e) => setDiscountValue(e.target.value)}
                                        required
                                    />
                                </div>
                            </div>

                            {selectedProduct && (
                                <div className="rounded-lg border bg-orange-50 p-3 text-sm dark:bg-orange-950/30">
                                    <div className="flex items-center justify-between">
                                        <span className="text-muted-foreground">Harga Normal:</span>
                                        <span className="line-through">{formatCurrency(selectedProduct.price)}</span>
                                    </div>
                                    <div className="mt-1 flex items-center justify-between font-bold text-orange-600">
                                        <span>Estimasi Harga Flash Sale:</span>
                                        <span>{formatCurrency(previewSalePrice)}</span>
                                    </div>
                                </div>
                            )}

                            <div className="grid gap-3 sm:grid-cols-2">
                                <div className="space-y-1.5">
                                    <Label htmlFor="item-quota">Kuota Flash Sale (Opsional)</Label>
                                    <Input
                                        id="item-quota"
                                        type="number"
                                        min="1"
                                        value={saleQuota}
                                        onChange={(e) => setSaleQuota(e.target.value)}
                                        placeholder="Kosongkan = ikut stok"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <Label htmlFor="item-max-user">Batas Beli / User (Opsional)</Label>
                                    <Input
                                        id="item-max-user"
                                        type="number"
                                        min="1"
                                        value={maxQtyPerUser}
                                        onChange={(e) => setMaxQtyPerUser(e.target.value)}
                                        placeholder="Kosongkan = tanpa batas"
                                    />
                                </div>
                            </div>

                            <label className="flex items-center gap-2 text-sm font-medium">
                                <input
                                    type="checkbox"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                />
                                Produk aktif dalam Flash Sale ini
                            </label>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                    Batal
                                </Button>
                                <Button type="submit" disabled={isSubmitting}>
                                    {isSubmitting ? 'Menyimpan...' : 'Simpan Produk Sale'}
                                </Button>
                            </DialogFooter>
                        </form>
                    </DialogContent>
                </Dialog>
            </div>
        </>
    );
}
