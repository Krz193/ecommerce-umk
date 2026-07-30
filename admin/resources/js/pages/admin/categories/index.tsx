import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { FolderTree, Plus, Search, Trash2 } from 'lucide-react';
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
import type { CategoryRow, Paginated } from '@/types';

type CategoriesIndexProps = {
    categories: Paginated<CategoryRow>;
    filters: {
        search: string;
        status: string;
    };
};

export default function CategoriesIndex({ categories, filters }: CategoriesIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');

    // Form Modal State
    const [isOpen, setIsOpen] = useState(false);
    const [editingCategory, setEditingCategory] = useState<CategoryRow | null>(null);
    const [name, setName] = useState('');
    const [slug, setSlug] = useState('');
    const [iconUrl, setIconUrl] = useState('');
    const [isActive, setIsActive] = useState(true);

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/categories', { search, status }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingCategory(null);
        setName('');
        setSlug('');
        setIconUrl('');
        setIsActive(true);
        setIsOpen(true);
    }

    function openEditModal(category: CategoryRow) {
        setEditingCategory(category);
        setName(category.name);
        setSlug(category.slug);
        setIconUrl(category.icon_url || '');
        setIsActive(category.is_active);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        const payload = {
            name,
            slug: slug || undefined,
            icon_url: iconUrl || undefined,
            is_active: isActive,
        };

        if (editingCategory) {
            router.patch(`/categories/${editingCategory.id}`, payload, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/categories', payload, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    function handleDelete(category: CategoryRow) {
        router.delete(`/categories/${category.id}`);
    }

    return (
        <>
            <Head title="Product Categories" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold flex items-center gap-2">
                            <FolderTree className="h-6 w-6" /> Product Categories
                        </h1>
                        <p className="text-sm text-muted-foreground">Manage catalog product categories across marketplace.</p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-1 h-4 w-4" /> Add Category
                    </Button>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Filters</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <Input
                                value={search}
                                onChange={(e) => setSearch(e.target.value)}
                                placeholder="Search category name or slug"
                            />
                            <select
                                className="h-9 rounded-md border bg-background px-3 text-sm"
                                value={status}
                                onChange={(e) => setStatus(e.target.value)}
                            >
                                <option value="">All Statuses</option>
                                <option value="active">Active</option>
                                <option value="inactive">Inactive</option>
                            </select>
                            <Button type="submit">
                                <Search className="mr-1 h-4 w-4" /> Filter
                            </Button>
                        </form>
                    </CardContent>
                </Card>

                <Card>
                    <CardContent className="overflow-x-auto pt-6">
                        <table className="w-full min-w-[700px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Category Name</th>
                                    <th className="pb-3 font-medium">Slug</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Linked Products</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {categories.data.length === 0 ? (
                                    <tr>
                                        <td colSpan={6} className="py-6 text-center text-muted-foreground">
                                            No categories found.
                                        </td>
                                    </tr>
                                ) : (
                                    categories.data.map((cat) => (
                                        <tr key={cat.id} className="border-b last:border-0">
                                            <td className="py-3 font-medium">
                                                <div className="flex items-center gap-2">
                                                    {cat.icon_url && (
                                                        <img src={cat.icon_url} alt="" className="h-6 w-6 rounded object-cover" />
                                                    )}
                                                    <span>{cat.name}</span>
                                                </div>
                                            </td>
                                            <td className="py-3 font-mono text-xs text-muted-foreground">{cat.slug}</td>
                                            <td className="py-3">
                                                <StatusBadge status={cat.is_active ? 'active' : 'inactive'} />
                                            </td>
                                            <td className="py-3">{cat.products_count} products</td>
                                            <td className="py-3">{formatDate(cat.created_at)}</td>
                                            <td className="py-3 text-right">
                                                <div className="flex justify-end gap-2">
                                                    <Button variant="outline" size="sm" onClick={() => openEditModal(cat)}>
                                                        Edit
                                                    </Button>
                                                    <ConfirmActionDialog
                                                        title={cat.products_count > 0 ? 'Deactivate Category?' : 'Delete Category?'}
                                                        description={
                                                            cat.products_count > 0
                                                                ? `This category is linked to ${cat.products_count} products. Deactivating will hide it from new category choices.`
                                                                : `Are you sure you want to delete category "${cat.name}"?`
                                                        }
                                                        actionLabel={cat.products_count > 0 ? 'Deactivate' : 'Delete'}
                                                        triggerLabel={cat.products_count > 0 ? 'Deactivate' : 'Delete'}
                                                        variant="destructive"
                                                        onConfirm={() => handleDelete(cat)}
                                                    />

                                                </div>
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>

                        <Pagination links={categories.links} />
                    </CardContent>
                </Card>
            </div>

            {/* Create / Edit Dialog */}
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[425px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingCategory ? 'Edit Category' : 'Create Category'}</DialogTitle>
                            <DialogDescription>
                                {editingCategory ? 'Update category details below.' : 'Add a new product category to the platform catalog.'}
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="cat_name">Category Name *</Label>
                                <Input
                                    id="cat_name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    placeholder="e.g. Kerajinan Tangan"
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="cat_slug">Slug (Optional)</Label>
                                <Input
                                    id="cat_slug"
                                    value={slug}
                                    onChange={(e) => setSlug(e.target.value)}
                                    placeholder="Auto-generated if empty"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="cat_icon">Icon URL (Optional)</Label>
                                <Input
                                    id="cat_icon"
                                    value={iconUrl}
                                    onChange={(e) => setIconUrl(e.target.value)}
                                    placeholder="https://example.com/icon.png"
                                />
                            </div>

                            <div className="flex items-center gap-2 pt-2">
                                <input
                                    type="checkbox"
                                    id="cat_active"
                                    checked={isActive}
                                    onChange={(e) => setIsActive(e.target.checked)}
                                    className="h-4 w-4 rounded border-gray-300"
                                />
                                <Label htmlFor="cat_active" className="cursor-pointer">
                                    Active / Visible in Catalog
                                </Label>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">{editingCategory ? 'Save Changes' : 'Create Category'}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
