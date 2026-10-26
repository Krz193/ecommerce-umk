import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Check, Plus, Shield, ShieldCheck, Trash2 } from 'lucide-react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
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

type Role = {
    id: string;
    name: string;
    slug: string;
    description: string | null;
    is_system: boolean;
    created_at: string;
};

type Permission = {
    id: string;
    name: string;
    slug: string;
    category: string;
    created_at: string;
};

type RolesIndexProps = {
    roles: Role[];
    permissions: Permission[];
    rolePermissionsMap: Record<string, string[]>;
    userRolesCount: Record<string, number>;
};

export default function RolesIndex({
    roles,
    permissions,
    rolePermissionsMap,
    userRolesCount,
}: RolesIndexProps) {
    const [selectedRole, setSelectedRole] = useState<Role>(roles[0] || null);

    // Selected permission IDs for the currently active role in the matrix editor
    const [activePermissionIds, setActivePermissionIds] = useState<string[]>(
        roles[0] ? rolePermissionsMap[roles[0].id] || [] : []
    );

    // Create Modal state
    const [isCreateOpen, setIsCreateOpen] = useState(false);
    const [createName, setCreateName] = useState('');
    const [createSlug, setCreateSlug] = useState('');
    const [createDesc, setCreateDesc] = useState('');
    const [createPermIds, setCreatePermIds] = useState<string[]>([]);

    function handleSelectRole(role: Role) {
        setSelectedRole(role);
        setActivePermissionIds(rolePermissionsMap[role.id] || []);
    }

    function togglePermission(permId: string) {
        setActivePermissionIds((prev) =>
            prev.includes(permId) ? prev.filter((id) => id !== permId) : [...prev, permId]
        );
    }

    function toggleCreatePermission(permId: string) {
        setCreatePermIds((prev) =>
            prev.includes(permId) ? prev.filter((id) => id !== permId) : [...prev, permId]
        );
    }

    function savePermissions() {
        if (!selectedRole) return;

        router.patch(`/roles/${selectedRole.id}`, {
            name: selectedRole.name,
            description: selectedRole.description,
            permission_ids: activePermissionIds,
        });
    }

    function handleCreateRole(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.post('/roles', {
            name: createName,
            slug: createSlug || undefined,
            description: createDesc || undefined,
            permission_ids: createPermIds,
        }, {
            onSuccess: () => {
                setIsCreateOpen(false);
                setCreateName('');
                setCreateSlug('');
                setCreateDesc('');
                setCreatePermIds([]);
            },
        });
    }

    function handleDeleteRole(role: Role) {
        router.delete(`/roles/${role.id}`);
    }

    // Group permissions by category
    const groupedPermissions = permissions.reduce<Record<string, Permission[]>>((acc, perm) => {
        const cat = perm.category || 'general';
        acc[cat] = acc[cat] || [];
        acc[cat].push(perm);
        return acc;
    }, {});

    return (
        <>
            <Head title="Roles & Permissions" />
            <div className="flex flex-1 flex-col gap-6 p-4">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-semibold flex items-center gap-2">
                            <ShieldCheck className="h-6 w-6 text-primary" /> Dynamic Roles & Permission Matrix
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Configure database-driven RBAC permissions for admin staff and system access.
                        </p>
                    </div>
                    <Button onClick={() => setIsCreateOpen(true)}>
                        <Plus className="mr-1 h-4 w-4" /> Create Custom Role
                    </Button>
                </div>

                <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
                    {/* Left Panel: Role List */}
                    <Card className="lg:col-span-1">
                        <CardHeader>
                            <CardTitle>System Roles</CardTitle>
                            <CardDescription>Select a role to configure its active permissions.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-2">
                            {roles.map((role) => {
                                const isSelected = selectedRole?.id === role.id;
                                const permCount = (rolePermissionsMap[role.id] || []).length;
                                const userCount = userRolesCount[role.id] || 0;

                                return (
                                    <div
                                        key={role.id}
                                        onClick={() => handleSelectRole(role)}
                                        className={`flex cursor-pointer items-center justify-between rounded-lg border p-3 transition-colors ${
                                            isSelected ? 'border-primary bg-primary/5 font-medium' : 'hover:bg-accent'
                                        }`}
                                    >
                                        <div>
                                            <div className="flex items-center gap-2">
                                                <Shield className="h-4 w-4 text-muted-foreground" />
                                                <span>{role.name}</span>
                                                {role.is_system && (
                                                    <span className="rounded bg-muted px-1.5 py-0.5 text-[10px] font-semibold uppercase">
                                                        System
                                                    </span>
                                                )}
                                            </div>
                                            <div className="mt-1 text-xs text-muted-foreground">
                                                {permCount} permissions • {userCount} assigned users
                                            </div>
                                        </div>

                                        {!role.is_system && (
                                            <ConfirmActionDialog
                                                title={`Delete Role ${role.name}?`}
                                                description="Are you sure you want to delete this custom role?"
                                                actionLabel="Delete Role"
                                                triggerLabel="Delete"
                                                variant="destructive"
                                                onConfirm={() => handleDeleteRole(role)}
                                            />
                                        )}
                                    </div>
                                );
                            })}
                        </CardContent>
                    </Card>

                    {/* Right Panel: Permission Matrix Editor */}
                    <Card className="lg:col-span-2">
                        {selectedRole ? (
                            <>
                                <CardHeader className="flex flex-row items-start justify-between">
                                    <div>
                                        <CardTitle className="text-xl">
                                            Permission Matrix: {selectedRole.name}
                                        </CardTitle>
                                        <CardDescription>
                                            {selectedRole.description || `Manage feature access for ${selectedRole.name}.`}
                                        </CardDescription>
                                    </div>
                                    <Button onClick={savePermissions}>
                                        <Check className="mr-1 h-4 w-4" /> Save Permission Matrix
                                    </Button>
                                </CardHeader>
                                <CardContent className="flex flex-col gap-6">
                                    {Object.entries(groupedPermissions).map(([category, perms]) => (
                                        <div key={category} className="rounded-lg border p-4">
                                            <h3 className="mb-3 text-sm font-semibold uppercase tracking-wider text-muted-foreground">
                                                Category: {category}
                                            </h3>
                                            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                                                {perms.map((perm) => {
                                                    const isChecked = activePermissionIds.includes(perm.id);

                                                    return (
                                                        <label
                                                            key={perm.id}
                                                            className={`flex cursor-pointer items-start gap-3 rounded-md border p-3 transition-colors ${
                                                                isChecked ? 'border-primary/50 bg-primary/5' : 'bg-background'
                                                            }`}
                                                        >
                                                            <input
                                                                type="checkbox"
                                                                checked={isChecked}
                                                                onChange={() => togglePermission(perm.id)}
                                                                className="mt-0.5 h-4 w-4 rounded border-gray-300"
                                                            />
                                                            <div>
                                                                <div className="text-sm font-medium">{perm.name}</div>
                                                                <div className="font-mono text-xs text-muted-foreground">{perm.slug}</div>
                                                            </div>
                                                        </label>
                                                    );
                                                })}
                                            </div>
                                        </div>
                                    ))}
                                </CardContent>
                            </>
                        ) : (
                            <CardContent className="py-12 text-center text-muted-foreground">
                                Select a role on the left to configure permissions.
                            </CardContent>
                        )}
                    </Card>
                </div>
            </div>

            {/* Create Custom Role Dialog */}
            <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
                <DialogContent className="sm:max-w-[500px]">
                    <form onSubmit={handleCreateRole}>
                        <DialogHeader>
                            <DialogTitle>Create Custom Role</DialogTitle>
                            <DialogDescription>
                                Add a new dynamic role and set its initial permissions.
                            </DialogDescription>
                        </DialogHeader>

                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="role_name">Role Name *</Label>
                                <Input
                                    id="role_name"
                                    value={createName}
                                    onChange={(e) => setCreateName(e.target.value)}
                                    placeholder="e.g. Asisten Wilayah UMK"
                                    required
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="role_slug">Slug (Optional)</Label>
                                <Input
                                    id="role_slug"
                                    value={createSlug}
                                    onChange={(e) => setCreateSlug(e.target.value)}
                                    placeholder="Auto-generated if empty"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label htmlFor="role_desc">Description</Label>
                                <Input
                                    id="role_desc"
                                    value={createDesc}
                                    onChange={(e) => setCreateDesc(e.target.value)}
                                    placeholder="Brief role responsibilities"
                                />
                            </div>

                            <div className="grid gap-2">
                                <Label>Initial Permissions</Label>
                                <div className="max-h-[180px] overflow-y-auto rounded-md border p-3">
                                    <div className="flex flex-col gap-2">
                                        {permissions.map((perm) => (
                                            <label key={perm.id} className="flex items-center gap-2 text-xs">
                                                <input
                                                    type="checkbox"
                                                    checked={createPermIds.includes(perm.id)}
                                                    onChange={() => toggleCreatePermission(perm.id)}
                                                    className="h-3.5 w-3.5 rounded border-gray-300"
                                                />
                                                <span>{perm.name}</span>
                                                <span className="font-mono text-muted-foreground">({perm.slug})</span>
                                            </label>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        </div>

                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setIsCreateOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">Create Role</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
