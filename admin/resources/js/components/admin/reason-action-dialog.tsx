import { FormEvent, useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';

type ReasonActionDialogProps = {
    title: string;
    description: string;
    actionLabel: string;
    triggerLabel: string;
    variant?: 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link';
    size?: 'default' | 'sm' | 'lg' | 'icon';
    onSubmit: (reason: string) => void;
};

export function ReasonActionDialog({
    title,
    description,
    actionLabel,
    triggerLabel,
    variant = 'default',
    size = 'sm',
    onSubmit,
}: ReasonActionDialogProps) {
    const [open, setOpen] = useState(false);
    const [reason, setReason] = useState('');

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();

        const trimmedReason = reason.trim();
        if (!trimmedReason) {
            return;
        }

        onSubmit(trimmedReason);
        setReason('');
        setOpen(false);
    }

    return (
        <>
            <Button variant={variant} size={size} onClick={() => setOpen(true)}>
                {triggerLabel}
            </Button>
            <Dialog open={open} onOpenChange={setOpen}>
                <DialogContent>
                    <DialogHeader>
                        <DialogTitle>{title}</DialogTitle>
                        <DialogDescription>{description}</DialogDescription>
                    </DialogHeader>
                    <form onSubmit={submit} className="space-y-4">
                        <div>
                            <label className="mb-1 block text-sm font-medium">Reason</label>
                            <textarea
                                className="min-h-28 w-full rounded-md border bg-background px-3 py-2 text-sm"
                                value={reason}
                                onChange={(event) => setReason(event.target.value)}
                                minLength={3}
                                maxLength={1000}
                                required
                            />
                        </div>
                        <DialogFooter>
                            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                                Cancel
                            </Button>
                            <Button type="submit">{actionLabel}</Button>
                        </DialogFooter>
                    </form>
                </DialogContent>
            </Dialog>
        </>
    );
}
