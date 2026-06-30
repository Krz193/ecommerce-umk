import { Badge } from '@/components/ui/badge';

const statusTone: Record<string, 'default' | 'secondary' | 'destructive' | 'outline'> = {
    active: 'default',
    published: 'default',
    paid: 'default',
    completed: 'default',
    pending: 'secondary',
    processing: 'secondary',
    draft: 'outline',
    shipped: 'outline',
    cancelled: 'destructive',
    failed: 'destructive',
    expired: 'destructive',
    suspended: 'destructive',
};

export function StatusBadge({ status }: { status: string | null | undefined }) {
    const label = status || '-';

    return <Badge variant={statusTone[label] ?? 'outline'}>{label}</Badge>;
}
