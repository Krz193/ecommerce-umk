import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { PackageSearch, Plus, Search, Trash2 } from 'lucide-react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { Pagination } from '@/components/admin/pagination';
import { ReasonActionDialog } from '@/components/admin/reason-action-dialog';
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
import { formatCurrency, formatDate } from '@/lib/format';
import type { Paginated, ProductRow } from '@/types';

type OptionItem = {
    id: string;
    name: string;
};

type ProductsIndexProps = {
    products: Paginated<ProductRow>;
    filters: {
        status: string;
        search: string;
    };
    categories?: OptionItem[];
    stores?: OptionItem[];
};

export default function ProductsIndex({ products, filters, categories = [], stores = [] }: ProductsIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');

    // Form Modal state
    const [isOpen, setIsOpen] = useState(false);
    const [editingProduct, setEditingProduct] = useState<ProductRow | null>(null);
    const [storeId, setStoreId] = useState('');
    const [categoryId, setCategoryId] = useState('');
    const [name, setName] = useState('');
    const [slug, setSlug] = useState('');
    const [price, setPrice] = useState('');
    const [stock, setStock] = useState('0');
    const [description, setDescription] = useState('');
    const [productStatus, setProductStatus] = useState('published');

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/products', { search, status }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingProduct(null);
        setStoreId(stores.length > 0 ? stores[0].id : '');
        setCategoryId(categories.length > 0 ? categories[0].id : '');
        setName('');
        setSlug('');
        setPrice('');
        setStock('0');
        setDescription('');
        setProductStatus('published');
        setIsOpen(true);
    }

    function openEditModal(product: ProductRow) {
        setEditingProduct(product);
        setName(product.name);
        setPrice(product.price);
        setStock(String(product.stock));
        setProductStatus(product.status);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        if (editingProduct) {
            router.patch(`/products/${editingProduct.id}`, {
                category_id: categoryId || undefined,
                name,
                slug: slug || undefined,
                price: Number(price),
                stock: Number(stock),
                description: description || undefined,
                status: productStatus,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/products', {
                store_id: storeId,
                category_id: categoryId || undefined,
                name,
                slug: slug || undefined,
                price: Number(price),
                stock: Number(stock),
                description: description || undefined,
                status: productStatus,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    function handleDelete(product: ProductRow) {
        router.delete(`/products/${product.id}`);
    }

    return (
        <>
            <Head title="Products" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold flex items-center gap-2">
                            <PackageSearch className="h-6 w-6" /> Product Management & Moderation
                        </h1>
                        <p className="text-sm text-muted-foreground">Inspect products, edit listing details, or add product on behalf of store.</p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-1 h-4 w-4" /> Create Product
                    </Button>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search product, store, or category" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="">All statuses</option>
                                <option value="published">Published</option>
                                <option value="draft">Draft</option>
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
                                                <Button variant="outline" size="sm" onClick={() => openEditModal(product)}>
                                                    Edit
                                                </Button>
                                                {product.archived_at ? (
                                                    <ReasonActionDialog
                                                        title="Restore product"
                                                        description={`Restore ${product.name}. This republishes the product to the marketplace.`}
                                                        actionLabel="Restore"
                                                        triggerLabel="Restore"
                                                        onSubmit={(reason) => router.patch(`/products/${product.id}/restore`, { reason })}
                                                    />
                                                ) : (
                                                    <ReasonActionDialog
                                                        title="Archive product"
                                                        description={`Archive ${product.name}. This removes it from public listing by setting it to draft.`}
                                                        actionLabel="Archive"
                                                        triggerLabel="Archive"
                                                        variant="destructive"
                                                        onSubmit={(reason) => router.patch(`/products/${product.id}/archive`, { reason })}
                                                    />
                                                )}
                                                <ConfirmActionDialog
                                                    title={`Delete ${product.name}?`}
                                                    description="Are you sure you want to delete this product? If it has order history, it will be archived instead."
                                                    actionLabel="Delete Product"
                                                    triggerLabel="Delete"
                                                    variant="destructive"
                                                    onConfirm={() => handleDelete(product)}
                                                />

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

            {/* Create / Edit Product Dialog */}
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[480px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingProduct ? 'Edit Product Details' : 'Create Product (Admin Listing)'}</DialogTitle>
                            <DialogDescription>
                                {editingProduct ? 'Update product information, price, and stock.' : 'Create product for store merchant.'}
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            {!editingProduct && (
                                <div className="grid gap-2">
                                    <Label htmlFor="prod_store">Target Store *</Label>
                                    {stores.length > 0 ? (
                                        <select
                                            id="prod_store"
                                            className="h-9 rounded-md border bg-background px-3 text-sm"
                                            value={storeId}
                                            onChange={(e) => setStoreId(e.target.value)}
                                            required
                                        >
                                            {stores.map((s) => (
                                                <option key={s.id} value={s.id}>{s.name}</option>
                                            ))}
                                        </select>
                                    ) : (
                                        <Input
                                            id="prod_store_manual"
                                            value={storeId}
                                            onChange={(e) => setStoreId(e.target.value)}
                                            placeholder="Store UUID"
                                            required
                                        />
                                    )}
                                </div>
                            )}

                            <div className="grid gap-2">
                                <Label htmlFor="prod_cat">Category</Label>
                                <select
                                    id="prod_cat"
                                    className="h-9 rounded-md border bg-background px-3 text-sm"
                                    value={categoryId}
                                    onChange={(e) => setCategoryId(e.target.value)}
                                >
                                    <option value="">-- No Category --</option>
                                    {categories.map((c) => (
                                        <option key={c.id} value={c.id}>{c.name}</option>
                                    ))}
                                </select>
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="prod_name">Product Name *</Label>
                                <Input
                                    id="prod_name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    placeholder="e.g. Keripik Singkong Balado 200g"
                                    required
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-3">
                                <div className="grid gap-2">
                                    <Label htmlFor="prod_price">Price (Rp) *</Label>
                                    <Input
                                        id="prod_price"
                                        type="number"
                                        min="0"
                                        value={price}
                                        onChange={(e) => setPrice(e.target.value)}
                                        placeholder="15000"
                                        required
                                    />
                                </div>
                                <div className="grid gap-2">
                                    <Label htmlFor="prod_stock">Stock *</Label>
                                    <Input
                                        id="prod_stock"
                                        type="number"
                                        min="0"
                                        value={stock}
                                        onChange={(e) => setStock(e.target.value)}
                                        placeholder="50"
                                        required
                                    />
                                </div>
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="prod_desc">Description</Label>
                                <Input
                                    id="prod_desc"
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                    placeholder="Short description"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="prod_status">Status</Label>
                                <select
                                    id="prod_status"
                                    className="h-9 rounded-md border bg-background px-3 text-sm"
                                    value={productStatus}
                                    onChange={(e) => setProductStatus(e.target.value)}
                                >
                                    <option value="published">Published</option>
                                    <option value="draft">Draft</option>
                                </select>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">{editingProduct ? 'Save Changes' : 'Create Product'}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
