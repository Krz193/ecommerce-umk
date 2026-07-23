import { FormEvent, useState } from 'react';
import { router } from '@inertiajs/react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import type { RefundCaseRow } from '@/types';

export function RefundCaseUpdateDialog({ refundCase }: { refundCase: RefundCaseRow }) {
    const [open, setOpen] = useState(false);
    const [status, setStatus] = useState(refundCase.status);
    const [reason, setReason] = useState('');
    const [adminNotes, setAdminNotes] = useState(refundCase.admin_notes || '');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        const trimmedReason = reason.trim();
        if (!trimmedReason) {
            return;
        }

        router.patch(`/refund-cases/${refundCase.case_key}`, {
            status,
            reason: trimmedReason,
            admin_notes: adminNotes,
        });
        setReason('');
        setOpen(false);
    }

    return (
        <>
            <Button variant="outline" size="sm" onClick={() => setOpen(true)}>
                Update
            </Button>
            <Dialog open={open} onOpenChange={setOpen}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>Update refund case</DialogTitle>
                        <DialogDescription>Update manual case status and record the reason in audit logs.</DialogDescription>
                    </DialogHeader>
                    <form onSubmit={submit} className="space-y-4">
                        <div>
                            <label className="mb-1 block text-sm font-medium">Status</label>
                            <select className="h-9 w-full rounded-md border bg-background px-3 text-sm" value={status} onChange={(event) => setStatus(event.target.value)}>
                                <option value="requested">Requested</option>
                                <option value="open">Open</option>
                                <option value="reviewing">Reviewing</option>
                                <option value="resolved">Resolved</option>
                                <option value="rejected">Rejected</option>
                            </select>
                        </div>
                        <div>
                            <label className="mb-1 block text-sm font-medium">Reason</label>
                            <textarea
                                className="min-h-24 w-full rounded-md border bg-background px-3 py-2 text-sm"
                                value={reason}
                                onChange={(event) => setReason(event.target.value)}
                                minLength={3}
                                maxLength={2000}
                                required
                            />
                        </div>
                        <div>
                            <label className="mb-1 block text-sm font-medium">Admin Notes</label>
                            <textarea
                                className="min-h-24 w-full rounded-md border bg-background px-3 py-2 text-sm"
                                value={adminNotes}
                                onChange={(event) => setAdminNotes(event.target.value)}
                                maxLength={4000}
                            />
                        </div>
                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">Save Update</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
