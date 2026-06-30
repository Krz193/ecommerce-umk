import { Head, Link, router } from '@inertiajs/react';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency, formatDate } from '@/lib/format';
import type { ProductRow } from '@/types';

type ProductImage = {
    id: string;
    image_url: string;
    sort_order: number;
    created_at: string;
};

type ProductShowProps = {
    product: ProductRow & {
        description: string | null;
        slug: string;
        weight: string | null;
        updated_at: string;
    };
    images: ProductImage[];
};

export default function ProductShow({ product, images }: ProductShowProps) {
    function archive() {
        if (confirm(`Archive ${product.name}?`)) {
            router.patch(`/products/${product.id}/archive`);
        }
    }

    function restore() {
        if (confirm(`Restore ${product.name}?`)) {
            router.patch(`/products/${product.id}/restore`);
        }
    }

    return (
        <>
            <Head title={product.name} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <div className="mb-2 flex gap-2">
                            <StatusBadge status={product.status} />
                            {product.archived_at && <StatusBadge status="archived" />}
                        </div>
                        <h1 className="text-2xl font-semibold">{product.name}</h1>
                        <p className="text-sm text-muted-foreground">{product.store_name} · {product.category_name || 'Uncategorized'}</p>
                    </div>
                    <div className="flex gap-2">
                        {product.archived_at ? (
                            <Button onClick={restore}>Restore</Button>
                        ) : (
                            <Button variant="destructive" onClick={archive}>Archive</Button>
                        )}
                    </div>
                </div>

                <div className="grid gap-4 xl:grid-cols-[380px_1fr]">
                    <Card>
                        <CardHeader><CardTitle>Thumbnail</CardTitle></CardHeader>
                        <CardContent>
                            {product.thumbnail_url ? (
                                <img src={product.thumbnail_url} alt={product.name} className="aspect-square w-full rounded-md object-cover" />
                            ) : (
                                <div className="flex aspect-square items-center justify-center rounded-md border text-sm text-muted-foreground">No thumbnail</div>
                            )}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Product Information</CardTitle></CardHeader>
                        <CardContent className="grid gap-3 text-sm md:grid-cols-2">
                            <Info label="Slug" value={product.slug} />
                            <Info label="Price" value={formatCurrency(product.price)} />
                            <Info label="Stock" value={String(product.stock)} />
                            <Info label="Weight" value={product.weight || '-'} />
                            <Info label="Created" value={formatDate(product.created_at)} />
                            <Info label="Updated" value={formatDate(product.updated_at)} />
                            <div className="md:col-span-2">
                                <Info label="Description" value={product.description || '-'} />
                            </div>
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader><CardTitle>Images</CardTitle></CardHeader>
                    <CardContent>
                        <div className="grid gap-3 sm:grid-cols-2 md:grid-cols-4 xl:grid-cols-6">
                            {images.map((image) => (
                                <a key={image.id} href={image.image_url} target="_blank" rel="noreferrer" className="block">
                                    <img src={image.image_url} alt={product.name} className="aspect-square rounded-md border object-cover" />
                                </a>
                            ))}
                        </div>
                        {images.length === 0 && <div className="text-sm text-muted-foreground">No images uploaded.</div>}
                    </CardContent>
                </Card>

                <Button asChild variant="outline" className="w-fit">
                    <Link href="/products">Back to products</Link>
                </Button>
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

ProductShow.layout = {
    breadcrumbs: [
        {
            title: 'Products',
            href: '/products',
        },
    ],
};
