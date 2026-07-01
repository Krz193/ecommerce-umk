import { FormEvent, useState } from 'react';
import { Head, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { formatDate } from '@/lib/format';
import type { AuditLogRow, Paginated } from '@/types';

type AuditLogsIndexProps = {
    logs: Paginated<AuditLogRow>;
    filters: {
        action: string;
        target_type: string;
    };
};

export default function AuditLogsIndex({ logs, filters }: AuditLogsIndexProps) {
    const [action, setAction] = useState(filters.action || '');
    const [targetType, setTargetType] = useState(filters.target_type || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/audit-logs', { action, target_type: targetType }, { preserveState: true, replace: true });
    }

    return (
        <>
            <Head title="Audit Logs" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Audit Logs</h1>
                    <p className="text-sm text-muted-foreground">Moderation and manual operation history with admin reason.</p>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="flex flex-col gap-3 md:flex-row">
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={targetType} onChange={(event) => setTargetType(event.target.value)}>
                                <option value="">All targets</option>
                                <option value="store">Store</option>
                                <option value="product">Product</option>
                                <option value="order">Order</option>
                            </select>
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={action} onChange={(event) => setAction(event.target.value)}>
                                <option value="">All actions</option>
                                <option value="store.approve">Store approve</option>
                                <option value="store.unsuspend">Store unsuspend</option>
                                <option value="store.suspend">Store suspend</option>
                                <option value="product.archive">Product archive</option>
                                <option value="product.restore">Product restore</option>
                                <option value="refund_case.create">Refund case create</option>
                                <option value="refund_case.update">Refund case update</option>
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
                                    <th className="pb-3 font-medium">Time</th>
                                    <th className="pb-3 font-medium">Admin</th>
                                    <th className="pb-3 font-medium">Action</th>
                                    <th className="pb-3 font-medium">Target</th>
                                    <th className="pb-3 font-medium">Reason</th>
                                </tr>
                            </thead>
                            <tbody>
                                {logs.data.map((log) => (
                                    <tr key={log.id} className="border-b last:border-0">
                                        <td className="py-3">{formatDate(log.created_at)}</td>
                                        <td className="py-3">
                                            <div>{log.admin_name}</div>
                                            <div className="text-xs text-muted-foreground">{log.admin_email}</div>
                                        </td>
                                        <td className="py-3">{log.action}</td>
                                        <td className="py-3">
                                            <div>{log.target_type}</div>
                                            <div className="font-mono text-xs text-muted-foreground">{log.target_id}</div>
                                        </td>
                                        <td className="max-w-md py-3">{log.reason}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {logs.data.length === 0 && <div className="py-10 text-center text-sm text-muted-foreground">No audit logs found.</div>}
                    </CardContent>
                </Card>

                <Pagination links={logs.links} />
            </div>
        </>
    );
}

AuditLogsIndex.layout = {
    breadcrumbs: [
        {
            title: 'Audit Logs',
            href: '/audit-logs',
        },
    ],
};
