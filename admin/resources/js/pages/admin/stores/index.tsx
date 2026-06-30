import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
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

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/stores', { search, status }, { preserveState: true, replace: true });
    }

    function approve(store: StoreRow) {
        const action = store.status === 'suspended' ? 'Unsuspend' : 'Approve';

        if (confirm(`${action} ${store.name}?`)) {
            router.patch(`/stores/${store.id}/approve`);
        }
    }

    function suspend(store: StoreRow) {
        if (confirm(`Suspend ${store.name}?`)) {
            router.patch(`/stores/${store.id}/suspend`);
        }
    }

    return (
        <>
            <Head title="Stores" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Store Moderation</h1>
                    <p className="text-sm text-muted-foreground">Approve active sellers and suspend problematic stores.</p>
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
                                                {store.status !== 'active' && (
                                                    <Button size="sm" onClick={() => approve(store)}>
                                                        {store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                                                    </Button>
                                                )}
                                                {store.status !== 'suspended' && (
                                                    <Button variant="destructive" size="sm" onClick={() => suspend(store)}>Suspend</Button>
                                                )}
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
        </>
    );
}

StoresIndex.layout = {
    breadcrumbs: [
        {
            title: 'Stores',
            href: '/stores',
        },
    ],
};
