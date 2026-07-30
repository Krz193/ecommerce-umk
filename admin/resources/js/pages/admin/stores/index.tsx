import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Plus, Search, Trash2 } from 'lucide-react';
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
import { formatDate } from '@/lib/format';
import type { Paginated, StoreRow } from '@/types';

type StoresIndexProps = {
    stores: Paginated<StoreRow>;
    filters: {
        status: string;
        search: string;
    };
};

export default function StoresIndex({ stores, filters }: StoresIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [status, setStatus] = useState(filters.status || '');

    // Form Modal state
    const [isOpen, setIsOpen] = useState(false);
    const [editingStore, setEditingStore] = useState<StoreRow | null>(null);
    const [ownerId, setOwnerId] = useState('');
    const [name, setName] = useState('');
    const [slug, setSlug] = useState('');
    const [phone, setPhone] = useState('');
    const [address, setAddress] = useState('');
    const [storeStatus, setStoreStatus] = useState('active');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/stores', { search, status }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingStore(null);
        setOwnerId('');
        setName('');
        setSlug('');
        setPhone('');
        setAddress('');
        setStoreStatus('active');
        setIsOpen(true);
    }

    function openEditModal(store: StoreRow) {
        setEditingStore(store);
        setName(store.name);
        setSlug(store.slug);
        setPhone(store.phone || '');
        setAddress(store.address || '');
        setStoreStatus(store.status);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        if (editingStore) {
            router.patch(`/stores/${editingStore.id}`, {
                name,
                slug: slug || undefined,
                phone: phone || undefined,
                address: address || undefined,
                status: storeStatus,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/stores', {
                owner_id: ownerId,
                name,
                slug: slug || undefined,
                phone: phone || undefined,
                address: address || undefined,
                status: storeStatus,
            }, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    function handleDelete(store: StoreRow) {
        router.delete(`/stores/${store.id}`);
    }

    return (
        <>
            <Head title="Stores" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold">Store Moderation & Management</h1>
                        <p className="text-sm text-muted-foreground">Approve active sellers, edit store details, or create store for offline UMK.</p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <Plus className="mr-1 h-4 w-4" /> Create Store
                    </Button>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Filters</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search store, slug, or owner" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="">All statuses</option>
                                <option value="pending">Pending</option>
                                <option value="active">Active</option>
                                <option value="suspended">Suspended</option>
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
                        <table className="w-full min-w-[900px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Store</th>
                                    <th className="pb-3 font-medium">Owner</th>
                                    <th className="pb-3 font-medium">Contact</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Detail</th>
                                    <th className="pb-3 text-right font-medium">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {stores.data.map((store) => (
                                    <tr key={store.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/stores/${store.id}`} className="font-medium hover:underline">
                                                {store.name}
                                            </Link>
                                            <div className="text-xs text-muted-foreground">{store.slug}</div>
                                        </td>
                                        <td className="py-3">{store.owner_name || '-'}</td>
                                        <td className="py-3">
                                            <div>{store.phone || '-'}</div>
                                            <div className="max-w-xs truncate text-xs text-muted-foreground">{store.address || '-'}</div>
                                        </td>
                                        <td className="py-3"><StatusBadge status={store.status} /></td>
                                        <td className="py-3">{formatDate(store.created_at)}</td>
                                        <td className="py-3 text-right">
                                            <Button asChild variant="outline" size="sm">
                                                <Link href={`/stores/${store.id}`}>Detail</Link>
                                            </Button>
                                        </td>
                                        <td className="py-3">
                                            <div className="flex justify-end gap-2">
                                                <Button variant="outline" size="sm" onClick={() => openEditModal(store)}>
                                                    Edit
                                                </Button>
                                                {store.status !== 'active' && (
                                                    <ConfirmActionDialog
                                                        title={`${store.status === 'suspended' ? 'Unsuspend' : 'Approve'} store`}
                                                        description={`${store.status === 'suspended' ? 'Unsuspend' : 'Approve'} ${store.name}. This updates the live marketplace store status.`}
                                                        actionLabel={store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                                                        triggerLabel={store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                                                        onConfirm={() => router.patch(`/stores/${store.id}/approve`)}
                                                    />
                                                )}
                                                {store.status !== 'suspended' && (
                                                    <ReasonActionDialog
                                                        title="Suspend store"
                                                        description={`Suspend ${store.name}. This removes the store from active operation until it is unsuspended.`}
                                                        actionLabel="Suspend"
                                                        triggerLabel="Suspend"
                                                        variant="destructive"
                                                        onSubmit={(reason) => router.patch(`/stores/${store.id}/suspend`, { reason })}
                                                    />
                                                )}
                                                <ConfirmActionDialog
                                                    title={`Delete ${store.name}?`}
                                                    description="Are you sure you want to delete this store? If it has transactions, it will be suspended instead."
                                                    actionLabel="Delete Store"
                                                    triggerLabel="Delete"
                                                    variant="destructive"
                                                    onConfirm={() => handleDelete(store)}
                                                />

                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {stores.data.length === 0 && (
                            <div className="py-10 text-center text-sm text-muted-foreground">No stores found.</div>
                        )}
                    </CardContent>
                </Card>

                <Pagination links={stores.links} />
            </div>

            {/* Create / Edit Store Dialog */}
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[480px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingStore ? 'Edit Store Details' : 'Create Store (Admin Onboarding)'}</DialogTitle>
                            <DialogDescription>
                                {editingStore ? 'Update store metadata and contact information.' : 'Create store directly for seller user.'}
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            {!editingStore && (
                                <div className="grid gap-2">
                                    <Label htmlFor="owner_id">Owner User ID (UUID) *</Label>
                                    <Input
                                        id="owner_id"
                                        value={ownerId}
                                        onChange={(e) => setOwnerId(e.target.value)}
                                        placeholder="User UUID from Users page"
                                        required
                                    />
                                </div>
                            )}

                            <div className="grid gap-2">
                                <Label htmlFor="store_name">Store Name *</Label>
                                <Input
                                    id="store_name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    placeholder="e.g. Toko Kerajinan Bambu"
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="store_slug">Slug (Optional)</Label>
                                <Input
                                    id="store_slug"
                                    value={slug}
                                    onChange={(e) => setSlug(e.target.value)}
                                    placeholder="Auto-generated if empty"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="store_phone">Phone</Label>
                                <Input
                                    id="store_phone"
                                    value={phone}
                                    onChange={(e) => setPhone(e.target.value)}
                                    placeholder="08123456789"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="store_address">Address</Label>
                                <Input
                                    id="store_address"
                                    value={address}
                                    onChange={(e) => setAddress(e.target.value)}
                                    placeholder="Full business address"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="store_status">Initial Status</Label>
                                <select
                                    id="store_status"
                                    className="h-9 rounded-md border bg-background px-3 text-sm"
                                    value={storeStatus}
                                    onChange={(e) => setStoreStatus(e.target.value)}
                                >
                                    <option value="active">Active</option>
                                    <option value="pending">Pending</option>
                                    <option value="suspended">Suspended</option>
                                </select>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">{editingStore ? 'Save Changes' : 'Create Store'}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
