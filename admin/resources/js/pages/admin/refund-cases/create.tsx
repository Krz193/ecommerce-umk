import { FormEvent, useState } from 'react';
import { Head, Link, router } from '@inertiajs/react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';

export default function RefundCaseCreate({ orderId }: { orderId: string }) {
    const [order, setOrder] = useState(orderId || '');
    const [reason, setReason] = useState('');
    const [adminNotes, setAdminNotes] = useState('');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        router.post('/refund-cases', {
            order_id: order,
            reason,
            admin_notes: adminNotes,
        });
    }

    return (
        <>
            <Head title="Create Refund Case" />
            <div className="flex flex-1 flex-col gap-4 p-4">
                <div>
                    <h1 className="text-2xl font-semibold">Create Refund Case</h1>
                    <p className="text-sm text-muted-foreground">Track manual cancellation/refund handling without mutating payment settlement.</p>
                </div>

                <Card className="max-w-3xl">
                    <CardHeader><CardTitle>Case Details</CardTitle></CardHeader>
                    <CardContent>
                        <form onSubmit={submit} className="space-y-4">
                            <div>
                                <label className="mb-1 block text-sm font-medium">Order ID</label>
                                <Input value={order} onChange={(event) => setOrder(event.target.value)} required />
                            </div>
                            <div>
                                <label className="mb-1 block text-sm font-medium">Reason</label>
                                <textarea className="min-h-28 w-full rounded-md border bg-background px-3 py-2 text-sm" value={reason} onChange={(event) => setReason(event.target.value)} required />
                            </div>
                            <div>
                                <label className="mb-1 block text-sm font-medium">Admin Notes</label>
                                <textarea className="min-h-28 w-full rounded-md border bg-background px-3 py-2 text-sm" value={adminNotes} onChange={(event) => setAdminNotes(event.target.value)} />
                            </div>
                            <div className="flex gap-2">
                                <Button type="submit">Create Case</Button>
                                <Button asChild variant="outline">
                                    <Link href="/refund-cases">Cancel</Link>
                                </Button>
                            </div>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </>
    );
}

RefundCaseCreate.layout = {
    breadcrumbs: [
        {
            title: 'Refund Cases',
            href: '/refund-cases',
        },
    ],
};
