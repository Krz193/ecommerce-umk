import { useState } from 'react';
import { Button } from '@/components/ui/button';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';

type ConfirmActionDialogProps = {
    title: string;
    description: string;
    actionLabel: string;
    triggerLabel: string;
    variant?: 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link';
    size?: 'default' | 'sm' | 'lg' | 'icon';
    onConfirm: () => void;
};

export function ConfirmActionDialog({
    title,
    description,
    actionLabel,
    triggerLabel,
    variant = 'default',
    size = 'sm',
    onConfirm,
}: ConfirmActionDialogProps) {
    const [open, setOpen] = useState(false);

    function confirm() {
        onConfirm();
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
                    <DialogFooter>
                        <Button type="button" variant="outline" onClick={() => setOpen(false)}>
                            Cancel
                        </Button>
                        <Button type="button" onClick={confirm}>
                            {actionLabel}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </>
    );
}
