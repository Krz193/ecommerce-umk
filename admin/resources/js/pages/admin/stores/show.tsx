import { Head, Link, router } from '@inertiajs/react';
import { ConfirmActionDialog } from '@/components/admin/confirm-action-dialog';
import { ReasonActionDialog } from '@/components/admin/reason-action-dialog';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatCurrency } from '@/lib/format';
import type { ProductRow, StoreRow } from '@/types';

type AssistantRow = {
    id: string;
    full_name: string;
    phone: string | null;
    role: string;
    assigned_at: string;
};

type CandidateUser = {
    id: string;
    full_name: string;
    phone: string | null;
    role: string;
};

type StoreShowProps = {
    store: StoreRow & {
        description: string | null;
        owner_username: string | null;
        payout_provider: string | null;
        payout_account_name: string | null;
        payout_account_number: string | null;
    };
    metrics: Record<string, number>;
    recentProducts: ProductRow[];
    assistants?: AssistantRow[];
    candidateUsers?: CandidateUser[];
};

export default function StoreShow({ store, metrics, recentProducts, assistants = [], candidateUsers = [] }: StoreShowProps) {
    const handleAssignAssistant = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const userId = formData.get('user_id') as string;
        if (!userId) return;

        router.post(`/stores/${store.id}/assistants`, { user_id: userId });
    };

    return (
        <>
            <Head title={store.name} />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-start">
                    <div>
                        <div className="mb-2"><StatusBadge status={store.status} /></div>
                        <h1 className="text-2xl font-semibold">{store.name}</h1>
                        <p className="text-sm text-muted-foreground">{store.slug}</p>
                    </div>
                    <div className="flex gap-2">
                        {store.status !== 'active' && (
                            <ConfirmActionDialog
                                title={`${store.status === 'suspended' ? 'Unsuspend' : 'Approve'} store`}
                                description={`${store.status === 'suspended' ? 'Unsuspend' : 'Approve'} ${store.name}. This updates the live marketplace store status.`}
                                actionLabel={store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                                triggerLabel={store.status === 'suspended' ? 'Unsuspend' : 'Approve'}
                                size="default"
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
                                size="default"
                                onSubmit={(reason) => router.patch(`/stores/${store.id}/suspend`, { reason })}
                            />
                        )}
                    </div>
                </div>

                <div className="grid gap-3 md:grid-cols-4">
                    {Object.entries(metrics).map(([key, value]) => (
                        <Card key={key} className="gap-2 py-4">
                            <CardHeader className="px-4">
                                <CardTitle className="text-sm capitalize text-muted-foreground">{key.replaceAll('_', ' ')}</CardTitle>
                            </CardHeader>
                            <CardContent className="px-4 text-2xl font-semibold">{value}</CardContent>
                        </Card>
                    ))}
                </div>

                <div className="grid gap-4 xl:grid-cols-2">
                    <Card>
                        <CardHeader><CardTitle>Store Information</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Owner" value={store.owner_name || '-'} />
                            <Info label="Owner Phone" value={store.owner_phone || '-'} />
                            <Info label="Store Phone" value={store.phone || '-'} />
                            <Info label="Address" value={store.address || '-'} />
                            <Info label="Description" value={store.description || '-'} />
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader><CardTitle>Payout Information</CardTitle></CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Info label="Provider" value={store.payout_provider || '-'} />
                            <Info label="Account Name" value={store.payout_account_name || '-'} />
                            <Info label="Account Number" value={store.payout_account_number || '-'} />
                        </CardContent>
                    </Card>
                </div>

                {/* Section Asisten UMK */}
                <Card>
                    <CardHeader className="flex flex-row items-center justify-between">
                        <div>
                            <CardTitle className="text-base">Asisten UMK (Pendamping Toko)</CardTitle>
                            <p className="text-xs text-muted-foreground mt-1">Daftar pengguna yang ditugaskan sebagai asisten pendamping untuk toko UMK ini.</p>
                        </div>
                    </CardHeader>
                    <CardContent className="space-y-4">
                        <form onSubmit={handleAssignAssistant} className="flex flex-wrap gap-2 items-center bg-muted/30 p-3 rounded-lg border">
                            <select
                                name="user_id"
                                required
                                className="flex-1 h-9 rounded-md border border-input bg-background px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                            >
                                <option value="">-- Pilih Pengguna untuk Dijadikan Asisten UMK --</option>
                                {candidateUsers.map((user) => (
                                    <option key={user.id} value={user.id}>
                                        {user.full_name} ({user.role}) - {user.phone || 'Tanpa No HP'}
                                    </option>
                                ))}
                            </select>
                            <Button type="submit" size="sm">Tugaskan Sebagai Asisten</Button>
                        </form>

                        {assistants.length === 0 ? (
                            <p className="text-xs text-muted-foreground py-2 italic text-center">Belum ada Asisten UMK yang ditugaskan untuk toko ini.</p>
                        ) : (
                            <div className="overflow-x-auto">
                                <table className="w-full text-sm">
                                    <thead className="border-b text-left text-muted-foreground">
                                        <tr>
                                            <th className="pb-2 font-medium">Nama Asisten</th>
                                            <th className="pb-2 font-medium">No. Telepon</th>
                                            <th className="pb-2 font-medium">Peran Akun</th>
                                            <th className="pb-2 font-medium">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {assistants.map((assistant) => (
                                            <tr key={assistant.id} className="border-b last:border-0">
                                                <td className="py-2.5 font-medium">{assistant.full_name}</td>
                                                <td className="py-2.5">{assistant.phone || '-'}</td>
                                                <td className="py-2.5">
                                                    <span className="inline-flex items-center rounded-full bg-purple-50 px-2 py-0.5 text-xs font-semibold text-purple-700 ring-1 ring-inset ring-purple-600/20">
                                                        {assistant.role}
                                                    </span>
                                                </td>
                                                <td className="py-2.5">
                                                    <ConfirmActionDialog
                                                        title="Hapus Penugasan Asisten"
                                                        description={`Apakah Anda yakin ingin menghapus penugasan ${assistant.full_name} sebagai asisten toko ${store.name}?`}
                                                        actionLabel="Hapus Penugasan"
                                                        triggerLabel="Hapus"
                                                        variant="destructive"
                                                        size="sm"
                                                        onConfirm={() => router.delete(`/stores/${store.id}/assistants/${assistant.id}`)}
                                                    />
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader><CardTitle>Recent Products</CardTitle></CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[760px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Product</th>
                                    <th className="pb-3 font-medium">Category</th>
                                    <th className="pb-3 font-medium">Price</th>
                                    <th className="pb-3 font-medium">Stock</th>
                                    <th className="pb-3 font-medium">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                {recentProducts.map((product) => (
                                    <tr key={product.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/products/${product.id}`} className="font-medium hover:underline">
                                                {product.name}
                                            </Link>
                                        </td>
                                        <td className="py-3">{product.category_name || '-'}</td>
                                        <td className="py-3">{formatCurrency(product.price)}</td>
                                        <td className="py-3">{product.stock}</td>
                                        <td className="py-3"><StatusBadge status={product.status} /></td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>
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

StoreShow.layout = {
    breadcrumbs: [
        {
            title: 'Stores',
            href: '/stores',
        },
    ],
};
