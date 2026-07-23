import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { formatDate } from '@/lib/format';
import type { MarketplaceUserRow, Paginated } from '@/types';

type UsersIndexProps = {
    users: Paginated<MarketplaceUserRow>;
    filters: {
        role: string;
        search: string;
    };
};

export default function UsersIndex({ users, filters }: UsersIndexProps) {
    const [search, setSearch] = useState(filters.search || '');
    const [role, setRole] = useState(filters.role || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/users', { search, role }, { preserveState: true, replace: true });
    }

    return (
        <>
            <Head title="Users" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Marketplace Users</h1>
                    <p className="text-sm text-muted-foreground">Read-only marketplace user lookup and related store/order context.</p>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search name, username, or phone" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={role} onChange={(event) => setRole(event.target.value)}>
                                <option value="">All roles</option>
                                <option value="buyer">Buyer</option>
                                <option value="seller">Seller</option>
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
                        <table className="w-full min-w-[800px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">User</th>
                                    <th className="pb-3 font-medium">Phone</th>
                                    <th className="pb-3 font-medium">Role</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Detail</th>
                                </tr>
                            </thead>
                            <tbody>
                                {users.data.map((user) => (
                                    <tr key={user.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/users/${user.id}`} className="font-medium hover:underline">{user.full_name}</Link>
                                            <div className="text-xs text-muted-foreground">{user.username || user.id}</div>
                                        </td>
                                        <td className="py-3">{user.phone || '-'}</td>
                                        <td className="py-3"><StatusBadge status={user.role} /></td>
                                        <td className="py-3">{formatDate(user.created_at)}</td>
                                        <td className="py-3 text-right">
                                            <Button asChild variant="outline" size="sm">
                                                <Link href={`/users/${user.id}`}>Detail</Link>
                                            </Button>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                <Pagination links={users.links} />
            </div>
        </>
    );
}

UsersIndex.layout = {
    breadcrumbs: [
        {
            title: 'Users',
            href: '/users',
        },
    ],
};
