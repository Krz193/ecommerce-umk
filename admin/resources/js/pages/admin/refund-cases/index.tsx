import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Search } from 'lucide-react';
import { Pagination } from '@/components/admin/pagination';
import { RefundCaseUpdateDialog } from '@/components/admin/refund-case-update-dialog';
import { StatusBadge } from '@/components/admin/status-badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { formatDate } from '@/lib/format';
import type { Paginated, RefundCaseRow } from '@/types';

type RefundCasesIndexProps = {
    cases: Paginated<RefundCaseRow>;
    filters: {
        status: string;
        search: string;
    };
};

export default function RefundCasesIndex({ cases, filters }: RefundCasesIndexProps) {
    const [status, setStatus] = useState(filters.status || '');
    const [search, setSearch] = useState(filters.search || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.get('/refund-cases', { status, search }, { preserveState: true, replace: true });
    }

    return (
        <>
            <Head title="Refund Cases" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div className="flex flex-col justify-between gap-3 md:flex-row md:items-center">
                    <div>
                        <h1 className="text-2xl font-semibold">Refund Cases</h1>
                        <p className="text-sm text-muted-foreground">Manual cancellation/refund tracking. Payment mutation remains outside this screen.</p>
                    </div>
                    <Button asChild>
                        <Link href="/refund-cases/create">Create Case</Link>
                    </Button>
                </div>

                <Card>
                    <CardHeader><CardTitle>Filters</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="flex flex-col gap-3 md:flex-row">
                            <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search order UUID" />
                            <select className="h-9 rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="">All statuses</option>
                                <option value="open">Open</option>
                                <option value="reviewing">Reviewing</option>
                                <option value="resolved">Resolved</option>
                                <option value="rejected">Rejected</option>
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
                                    <th className="pb-3 font-medium">Order</th>
                                    <th className="pb-3 font-medium">Status</th>
                                    <th className="pb-3 font-medium">Source</th>
                                    <th className="pb-3 font-medium">Type</th>
                                    <th className="pb-3 font-medium">Reason</th>
                                    <th className="pb-3 font-medium">Requester</th>
                                    <th className="pb-3 font-medium">Created</th>
                                    <th className="pb-3 text-right font-medium">Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {cases.data.map((refundCase) => (
                                    <tr key={refundCase.id} className="border-b last:border-0">
                                        <td className="py-3">
                                            <Link href={`/orders/${refundCase.order_id}`} className="font-mono text-xs hover:underline">{refundCase.order_id}</Link>
                                        </td>
                                        <td className="py-3"><StatusBadge status={refundCase.status} /></td>
                                        <td className="py-3 capitalize">{refundCase.source}</td>
                                        <td className="py-3 capitalize">{refundCase.requester_role} {refundCase.request_type}</td>
                                        <td className="max-w-md py-3">{refundCase.reason}</td>
                                        <td className="py-3">{refundCase.created_by_name}</td>
                                        <td className="py-3">{formatDate(refundCase.created_at)}</td>
                                        <td className="py-3 text-right">
                                            <div className="flex justify-end gap-2">
                                                <Button asChild variant="outline" size="sm">
                                                    <Link href={`/refund-cases/${refundCase.case_key}`}>Detail</Link>
                                                </Button>
                                                <RefundCaseUpdateDialog refundCase={refundCase} />
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {cases.data.length === 0 && <div className="py-10 text-center text-sm text-muted-foreground">No refund cases found.</div>}
                    </CardContent>
                </Card>

                <Pagination links={cases.links} />
            </div>
        </>
    );
}

RefundCasesIndex.layout = {
    breadcrumbs: [
        {
            title: 'Refund Cases',
            href: '/refund-cases',
        },
    ],
};
