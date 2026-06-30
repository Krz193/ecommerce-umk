import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { formatCurrency, formatDate } from '@/lib/format';
import type { Paginated, ProductRow } from '@/types';

type ProductsIndexProps = {
    products: Paginated<ProductRow>;
    filters: {
        status: string;
        search: string;
    };
};

export default function ProductsIndex({ products, filters }: ProductsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/products', { search, status }, { preserveState: true, replace: true });
    }

    function archive(product: ProductRow) {
        if (confirm(`Archive ${product.name}? This removes it from public listing by setting it to draft.`)) {
            router.patch(`/products/${product.id}/archive`);
        }
    }

    function restore(product: ProductRow) {
        if (confirm(`Restore ${product.name}?`)) {
            router.patch(`/products/${product.id}/restore`);
        }
    }

    return (
        <>
            <Head title="Products" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Product Moderation</h1>
                    <p className="text-sm text-muted-foreground">Inspect products, store context, stock, category, and visibility state.</p>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search product, store, or category" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="">All statuses</option>
                                <option value="published">Published</option>
                                <option value="draft">Draft</option>
                            </select>
                            <Button type="submit">
                                <Search />
                                Filter
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardContent className="overflow-x-auto pt-6">
                        <table className="w-full min-w-[980px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Product</th>
                                    <th className="pb-3 font-medium">Store</th>
                                    <th className="pb-3 font-medium">Category</th>
                                    <th className="pb-3 font-medium">Price</th>
                                    <th className="pb-3 font-medium">Stock</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {products.data.map((product) => (
                                    <tr key={product.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/products/${product.id}`} className="font-medium hover:underline">
                                                {product.name}
                                            </Link>
                                            {product.archived_at && <div className="text-xs text-destructive">Archived</div>}
                                        </td>
                                        <td className="py-3">{product.store_name}</td>
                                        <td className="py-3">{product.category_name || '-'}</td>
                                        <td className="py-3">{formatCurrency(product.price)}</td>
                                        <td className="py-3">{product.stock}</td>
                                        <td className="py-3"><StatusBadge status={product.status} /></td>
                                        <td className="py-3">{formatDate(product.created_at)}</td>
                                        <td className="py-3">
                                            <div className="flex justify-end gap-2">
                                                <Button asChild variant="outline" size="sm">
                                                    <Link href={`/products/${product.id}`}>Detail</Link>
                                                </Button>
                                                {product.archived_at ? (
                                                    <Button size="sm" onClick={() => restore(product)}>Restore</Button>
                                                ) : (
                                                    <Button variant="destructive" size="sm" onClick={() => archive(product)}>Archive</Button>
                                                )}
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {products.data.length === 0 && (
                            <div className="py-10 text-center text-sm text-muted-foreground">No products found.</div>
                        )}
                    </CardContent>
                </Card>

                <Pagination links={products.links} />
            </div>
        </>
    );
}

ProductsIndex.layout = {
    breadcrumbs: [
        {
            title: 'Products',
            href: '/products',
        },
    ],
};
