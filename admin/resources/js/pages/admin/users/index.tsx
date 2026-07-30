import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Plus, Search, UserPlus, Users } from 'lucide-react';
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

    // Form Modal state
    const [isOpen, setIsOpen] = useState(false);
    const [editingUser, setEditingUser] = useState<MarketplaceUserRow | null>(null);
    const [fullName, setFullName] = useState('');
    const [username, setUsername] = useState('');
    const [phone, setPhone] = useState('');
    const [userRole, setUserRole] = useState('buyer');

    function submitFilter(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        router.get('/users', { search, role }, { preserveState: true, replace: true });
    }

    function openCreateModal() {
        setEditingUser(null);
        setFullName('');
        setUsername('');
        setPhone('');
        setUserRole('buyer');
        setIsOpen(true);
    }

    function openEditModal(user: MarketplaceUserRow) {
        setEditingUser(user);
        setFullName(user.full_name);
        setUsername(user.username || '');
        setPhone(user.phone || '');
        setUserRole(user.role);
        setIsOpen(true);
    }

    function handleSave(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        const payload = {
            full_name: fullName,
            username: username || undefined,
            phone: phone || undefined,
            role: userRole,
        };

        if (editingUser) {
            router.patch(`/users/${editingUser.id}`, payload, {
                onSuccess: () => setIsOpen(false),
            });
        } else {
            router.post('/users', payload, {
                onSuccess: () => setIsOpen(false),
            });
        }
    }

    function handleDelete(user: MarketplaceUserRow) {
        router.delete(`/users/${user.id}`);
    }

    return (
        <>
            <Head title="Users" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold flex items-center gap-2">
                            <Users className="h-6 w-6" /> User Management
                        </h1>
                        <p className="text-sm text-muted-foreground">Manage marketplace users, update roles (buyer/seller/assistant/admin), and register staff.</p>
                    </div>
                    <Button onClick={openCreateModal}>
                        <UserPlus className="mr-1 h-4 w-4" /> Add User
                    </Button>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submitFilter} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search name, username, or phone" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={role} onChange={(event) => setRole(event.target.value)}>
                                <option value="">All roles</option>
                                <option value="buyer">Buyer</option>
                                <option value="seller">Seller</option>
                                <option value="assistant">Assistant</option>
                                <option value="admin">Admin</option>
                            </select>
                            <Button type="submit">
                                <Search className="mr-1 h-4 w-4" /> Filter
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
                                    <th className="pb-3 text-right font-medium">Actions</th>
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
                                        <td className="py-3">
                                            <div className="flex justify-end gap-2">
                                                <Button asChild variant="outline" size="sm">
                                                    <Link href={`/users/${user.id}`}>Detail</Link>
                                                </Button>
                                                <Button variant="outline" size="sm" onClick={() => openEditModal(user)}>
                                                    Edit
                                                </Button>
                                                <ConfirmActionDialog
                                                    title={`Delete ${user.full_name}?`}
                                                    description="Are you sure you want to delete this user? Users with linked stores or order records cannot be deleted."
                                                    actionLabel="Delete User"
                                                    triggerLabel="Delete"
                                                    variant="destructive"
                                                    onConfirm={() => handleDelete(user)}
                                                />
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {users.data.length === 0 && (
                            <div className="py-10 text-center text-sm text-muted-foreground">No users found.</div>
                        )}
                    </CardContent>
                </Card>

                <Pagination links={users.links} />
            </div>

            {/* Create / Edit User Dialog */}
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
                <DialogContent className="sm:max-w-[450px]">
                    <form onSubmit={handleSave}>
                        <DialogHeader>
                            <DialogTitle>{editingUser ? 'Edit User Details' : 'Create User Profile'}</DialogTitle>
                            <DialogDescription>
                                {editingUser ? 'Update user profile info and role.' : 'Register a new user profile manually.'}
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="user_fullname">Full Name *</Label>
                                <Input
                                    id="user_fullname"
                                    value={fullName}
                                    onChange={(e) => setFullName(e.target.value)}
                                    placeholder="e.g. Ahmad Fauzi"
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="user_username">Username</Label>
                                <Input
                                    id="user_username"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    placeholder="e.g. ahmad_fauzi"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="user_phone">Phone</Label>
                                <Input
                                    id="user_phone"
                                    value={phone}
                                    onChange={(e) => setPhone(e.target.value)}
                                    placeholder="08123456789"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="user_role">Role *</Label>
                                <select
                                    id="user_role"
                                    className="h-9 rounded-md border bg-background px-3 text-sm"
                                    value={userRole}
                                    onChange={(e) => setUserRole(e.target.value)}
                                >
                                    <option value="buyer">Buyer</option>
                                    <option value="seller">Seller</option>
                                    <option value="assistant">Assistant UMK</option>
                                    <option value="admin">Admin</option>
                                </select>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">{editingUser ? 'Save Changes' : 'Create User'}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
