import { useState, type FormEventHandler, type ChangeEvent } from 'react';
import { Head, useForm, router } from '@inertiajs/react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { formatDate } from '@/lib/format';
import { Calendar, Users, Video, Plus, Edit2, Trash2, UserPlus, CheckCircle2 } from 'lucide-react';

type Training = {
    id: string;
    title: string;
    description: string | null;
    instructor: string;
    schedule_at: string;
    location_or_url: string;
    max_participants: number;
    status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
    participants_count: number;
    participants: Array<{
        id: string;
        store_id: string;
        user_id: string;
        status: string;
        notes: string | null;
        registered_at: string;
        store: { id: string; name: string };
        user: { id: string; full_name: string; phone: string | null };
    }>;
};

type StoreOption = {
    id: string;
    name: string;
    owner_id: string;
    status: string;
};

type TrainingsIndexProps = {
    trainings: Training[];
    stores: StoreOption[];
};

export default function TrainingsIndex({ trainings, stores }: TrainingsIndexProps) {
    const [isCreateOpen, setIsCreateOpen] = useState(false);
    const [editingTraining, setEditingTraining] = useState<Training | null>(null);
    const [selectedTrainingId, setSelectedTrainingId] = useState<string | null>(null);

    // Derive active managing training from refreshed trainings list
    const managingParticipantsTraining = trainings.find((t) => t.id === selectedTrainingId) ?? null;

    // Form for Create & Edit Training
    const form = useForm<{
        title: string;
        description: string;
        instructor: string;
        schedule_at: string;
        location_or_url: string;
        max_participants: number;
        status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
    }>({
        title: '',
        description: '',
        instructor: '',
        schedule_at: '',
        location_or_url: 'Online via Zoom',
        max_participants: 50,
        status: 'upcoming',
    });

    // Form for Enrolling Store Participant
    const participantForm = useForm({
        store_id: stores[0]?.id ?? '',
        notes: '',
    });

    const openCreateDialog = () => {
        setEditingTraining(null);
        form.reset();
        form.setData({
            title: '',
            description: '',
            instructor: 'Tim Ahli / Instruktur UMK',
            schedule_at: new Date(Date.now() + 86400000 * 3).toISOString().slice(0, 16),
            location_or_url: 'Online via Zoom (Link akan dibagikan)',
            max_participants: 50,
            status: 'upcoming',
        });
        setIsCreateOpen(true);
    };

    const openEditDialog = (training: Training) => {
        setEditingTraining(training);
        form.setData({
            title: training.title,
            description: training.description ?? '',
            instructor: training.instructor,
            schedule_at: new Date(training.schedule_at).toISOString().slice(0, 16),
            location_or_url: training.location_or_url,
            max_participants: training.max_participants,
            status: training.status,
        });
        setIsCreateOpen(true);
    };

    const handleSubmitTraining: FormEventHandler = (e) => {
        e.preventDefault();
        if (editingTraining) {
            form.patch(`/trainings/${editingTraining.id}`, {
                preserveScroll: true,
                onSuccess: () => {
                    setIsCreateOpen(false);
                    setEditingTraining(null);
                },
            });
        } else {
            form.post('/trainings', {
                preserveScroll: true,
                onSuccess: () => {
                    setIsCreateOpen(false);
                },
            });
        }
    };

    const handleDeleteTraining = (training: Training) => {
        if (confirm(`Yakin ingin menghapus jadwal pelatihan "${training.title}"?`)) {
            router.delete(`/trainings/${training.id}`, { preserveScroll: true });
        }
    };

    const handleAddParticipant: FormEventHandler = (e) => {
        e.preventDefault();
        if (!managingParticipantsTraining) return;

        participantForm.post(`/trainings/${managingParticipantsTraining.id}/participants`, {
            preserveScroll: true,
            preserveState: true,
            onSuccess: () => {
                participantForm.reset();
            },
        });
    };

    const handleRemoveParticipant = (trainingId: string, participantId: string) => {
        if (confirm('Hapus toko ini dari daftar peserta pelatihan?')) {
            router.delete(`/trainings/${trainingId}/participants/${participantId}`, {
                preserveScroll: true,
                preserveState: true,
            });
        }
    };

    const totalUpcoming = trainings.filter((t) => t.status === 'upcoming').length;
    const totalParticipants = trainings.reduce((acc, t) => acc + (t.participants_count || 0), 0);

    return (
        <>
            <Head title="Manajemen Pelatihan UMK" />
            <div className="flex flex-1 flex-col gap-5 p-5">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">Manajemen Pelatihan & Pembinaan UMK</h1>
                        <p className="text-sm text-muted-foreground">
                            Kelola jadwal pelatihan bisnis, materi webinar, dan pendaftaran toko mitra UMK.
                        </p>
                    </div>
                    <Button onClick={openCreateDialog} className="gap-1.5 shadow-sm">
                        <Plus className="h-4 w-4" /> Tambah Pelatihan
                    </Button>
                </div>

                {/* Metrics */}
                <div className="grid gap-3 sm:grid-cols-3">
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Total Sesi Pelatihan</p>
                            <h3 className="mt-1 text-2xl font-bold">{trainings.length}</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Program pembinaan terdaftar</p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Pelatihan Akan Datang</p>
                            <h3 className="mt-1 text-2xl font-bold text-blue-600">{totalUpcoming} Sesi</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Siap diikuti toko UMK</p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardContent className="p-4">
                            <p className="text-xs font-medium text-muted-foreground">Total UMK Terdaftar</p>
                            <h3 className="mt-1 text-2xl font-bold text-emerald-600">{totalParticipants} Peserta</h3>
                            <p className="mt-1 text-xs text-muted-foreground">Akumulasi partisipasi toko</p>
                        </CardContent>
                    </Card>
                </div>

                {/* Trainings List */}
                <Card>
                    <CardHeader>
                        <CardTitle>Daftar Program Pelatihan UMK</CardTitle>
                    </CardHeader>
                    <CardContent className="overflow-x-auto">
                        <table className="w-full min-w-[900px] text-sm">
                            <thead className="border-b text-left text-muted-foreground">
                                <tr>
                                    <th className="pb-3 font-medium">Judul Pelatihan</th>
                                    <th className="pb-3 font-medium">Instruktur / Pemateri</th>
                                    <th className="pb-3 font-medium">Jadwal Pelaksanaan</th>
                                    <th className="pb-3 font-medium">Lokasi / Media</th>
                                    <th className="pb-3 text-center font-medium">Peserta / Kuota</th>
                                    <th className="pb-3 text-center font-medium">Status</th>
                                    <th className="pb-3 text-right font-medium">Aksi</th>
                                </tr>
                            </thead>
                            <tbody>
                                {trainings.map((training) => (
                                    <tr key={training.id} className="border-b transition hover:bg-muted/30 last:border-0">
                                        <td className="py-3.5">
                                            <div className="font-semibold text-foreground">{training.title}</div>
                                            {training.description && (
                                                <p className="mt-0.5 line-clamp-1 text-xs text-muted-foreground">{training.description}</p>
                                            )}
                                        </td>
                                        <td className="py-3.5 text-muted-foreground">{training.instructor}</td>
                                        <td className="py-3.5">
                                            <div className="flex items-center gap-1.5 font-medium">
                                                <Calendar className="h-3.5 w-3.5 text-muted-foreground" />
                                                {formatDate(training.schedule_at)}
                                            </div>
                                        </td>
                                        <td className="py-3.5">
                                            <div className="flex items-center gap-1.5 text-xs">
                                                <Video className="h-3.5 w-3.5 text-blue-600" />
                                                <span className="line-clamp-1 max-w-[180px]">{training.location_or_url}</span>
                                            </div>
                                        </td>
                                        <td className="py-3.5 text-center">
                                            <button
                                                onClick={() => setSelectedTrainingId(training.id)}
                                                className="inline-flex items-center gap-1 rounded-full bg-blue-50 px-2.5 py-1 text-xs font-semibold text-blue-700 hover:bg-blue-100"
                                            >
                                                <Users className="h-3 w-3" />
                                                {training.participants_count} / {training.max_participants} Toko
                                            </button>
                                        </td>
                                        <td className="py-3.5 text-center">
                                            <span
                                                className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold ${
                                                    training.status === 'upcoming'
                                                        ? 'bg-blue-100 text-blue-800'
                                                        : training.status === 'ongoing'
                                                          ? 'bg-amber-100 text-amber-800'
                                                          : training.status === 'completed'
                                                            ? 'bg-green-100 text-green-800'
                                                            : 'bg-gray-100 text-gray-800'
                                                }`}
                                            >
                                                {training.status.toUpperCase()}
                                            </span>
                                        </td>
                                        <td className="py-3.5 text-right">
                                            <div className="flex items-center justify-end gap-1.5">
                                                <Button
                                                    size="sm"
                                                    variant="outline"
                                                    onClick={() => setSelectedTrainingId(training.id)}
                                                    className="h-8 gap-1 text-xs"
                                                >
                                                    <UserPlus className="h-3.5 w-3.5" /> Peserta
                                                </Button>
                                                <Button
                                                    size="icon"
                                                    variant="ghost"
                                                    onClick={() => openEditDialog(training)}
                                                    className="h-8 w-8"
                                                >
                                                    <Edit2 className="h-3.5 w-3.5" />
                                                </Button>
                                                <Button
                                                    size="icon"
                                                    variant="ghost"
                                                    onClick={() => handleDeleteTraining(training)}
                                                    className="h-8 w-8 text-destructive hover:text-destructive"
                                                >
                                                    <Trash2 className="h-3.5 w-3.5" />
                                                </Button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                                {trainings.length === 0 && (
                                    <tr>
                                        <td colSpan={7} className="py-8 text-center text-muted-foreground">
                                            Belum ada program pelatihan yang dibuat. Klik tombol "+ Tambah Pelatihan" untuk memulai.
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </CardContent>
                </Card>

                {/* Dialog: Create / Edit Training */}
                <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
                    <DialogContent className="sm:max-w-[550px]">
                        <form onSubmit={handleSubmitTraining} className="space-y-4">
                            <DialogHeader>
                                <DialogTitle>{editingTraining ? 'Edit Program Pelatihan' : 'Tambah Pelatihan Baru'}</DialogTitle>
                                <DialogDescription>
                                    Lengkapi informasi agenda pelatihan bisnis dan pembinaan toko mitra UMK.
                                </DialogDescription>
                            </DialogHeader>

                            <div className="space-y-3">
                                <div>
                                    <Label htmlFor="title">Judul Pelatihan *</Label>
                                    <Input
                                        id="title"
                                        value={form.data.title}
                                        onChange={(e: ChangeEvent<HTMLInputElement>) => form.setData('title', e.target.value)}
                                        placeholder="Contoh: Strategi Pemasaran Digital & Foto Produk"
                                        required
                                    />
                                    {form.errors.title && <p className="text-xs text-destructive">{form.errors.title}</p>}
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <Label htmlFor="instructor">Pemateri / Instruktur *</Label>
                                        <Input
                                            id="instructor"
                                            value={form.data.instructor}
                                            onChange={(e: ChangeEvent<HTMLInputElement>) => form.setData('instructor', e.target.value)}
                                            placeholder="Nama narasumber ahli"
                                            required
                                        />
                                        {form.errors.instructor && <p className="text-xs text-destructive">{form.errors.instructor}</p>}
                                    </div>
                                    <div>
                                        <Label htmlFor="schedule_at">Jadwal Pelaksanaan *</Label>
                                        <Input
                                            id="schedule_at"
                                            type="datetime-local"
                                            value={form.data.schedule_at}
                                            onChange={(e: ChangeEvent<HTMLInputElement>) => form.setData('schedule_at', e.target.value)}
                                            required
                                        />
                                        {form.errors.schedule_at && <p className="text-xs text-destructive">{form.errors.schedule_at}</p>}
                                    </div>
                                </div>

                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <Label htmlFor="location_or_url">Media / Link Zoom / Lokasi *</Label>
                                        <Input
                                            id="location_or_url"
                                            value={form.data.location_or_url}
                                            onChange={(e: ChangeEvent<HTMLInputElement>) => form.setData('location_or_url', e.target.value)}
                                            placeholder="https://zoom.us/... atau Ruang Pelatihan"
                                            required
                                        />
                                    </div>
                                    <div>
                                        <Label htmlFor="max_participants">Kapasitas Maksimal (Toko) *</Label>
                                        <Input
                                            id="max_participants"
                                            type="number"
                                            min={1}
                                            max={500}
                                            value={form.data.max_participants}
                                            onChange={(e: ChangeEvent<HTMLInputElement>) => form.setData('max_participants', Number(e.target.value))}
                                            required
                                        />
                                    </div>
                                </div>

                                <div>
                                    <Label htmlFor="status">Status Pelatihan</Label>
                                    <select
                                        id="status"
                                        value={form.data.status}
                                        onChange={(e: ChangeEvent<HTMLSelectElement>) => form.setData('status', e.target.value as any)}
                                        className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                    >
                                        <option value="upcoming">Upcoming (Akan Datang)</option>
                                        <option value="ongoing">Ongoing (Sedang Berlangsung)</option>
                                        <option value="completed">Completed (Selesai)</option>
                                        <option value="cancelled">Cancelled (Dibatalkan)</option>
                                    </select>
                                </div>

                                <div>
                                    <Label htmlFor="description">Deskripsi & Silabus Materi</Label>
                                    <textarea
                                        id="description"
                                        rows={3}
                                        value={form.data.description}
                                        onChange={(e: ChangeEvent<HTMLTextAreaElement>) => form.setData('description', e.target.value)}
                                        placeholder="Tuliskan poin materi yang akan dipelajari..."
                                        className="w-full rounded-md border border-input bg-background p-2.5 text-sm"
                                    />
                                </div>
                            </div>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setIsCreateOpen(false)}>
                                    Batal
                                </Button>
                                <Button type="submit" disabled={form.processing}>
                                    {form.processing ? 'Menyimpan...' : (editingTraining ? 'Simpan Perubahan' : 'Publish Pelatihan')}
                                </Button>
                            </DialogFooter>
                        </form>
                    </DialogContent>
                </Dialog>

                {/* Dialog: Manage Participants for a Training */}
                {managingParticipantsTraining && (
                    <Dialog open={Boolean(managingParticipantsTraining)} onOpenChange={() => setSelectedTrainingId(null)}>
                        <DialogContent className="sm:max-w-[650px]">
                            <DialogHeader>
                                <DialogTitle>Kelola Peserta Toko Mitra UMK</DialogTitle>
                                <DialogDescription>
                                    Pelatihan: <strong className="text-foreground">{managingParticipantsTraining.title}</strong>
                                </DialogDescription>
                            </DialogHeader>

                            {/* Add Participant Form */}
                            <form onSubmit={handleAddParticipant} className="flex gap-2 rounded-lg border bg-muted/30 p-3">
                                <div className="flex-1">
                                    <select
                                        value={participantForm.data.store_id}
                                        onChange={(e: ChangeEvent<HTMLSelectElement>) => participantForm.setData('store_id', e.target.value)}
                                        className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                        required
                                    >
                                        <option value="">-- Pilih Toko UMK yang didaftarkan --</option>
                                        {stores.map((s) => (
                                            <option key={s.id} value={s.id}>
                                                {s.name}
                                            </option>
                                        ))}
                                    </select>
                                </div>
                                <Button type="submit" size="sm" disabled={participantForm.processing} className="gap-1">
                                    <Plus className="h-4 w-4" /> Daftarkan Toko
                                </Button>
                            </form>

                            {/* Enrolled Participants List */}
                            <div className="max-h-[300px] overflow-y-auto">
                                <table className="w-full text-sm">
                                    <thead className="border-b text-left text-xs text-muted-foreground">
                                        <tr>
                                            <th className="pb-2">Toko UMK Terdaftar</th>
                                            <th className="pb-2">Pemilik Toko</th>
                                            <th className="pb-2 text-center">Status</th>
                                            <th className="pb-2 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {managingParticipantsTraining.participants?.map((p) => (
                                            <tr key={p.id} className="border-b last:border-0">
                                                <td className="py-2.5 font-semibold text-primary">{p.store?.name}</td>
                                                <td className="py-2.5 text-xs text-muted-foreground">{p.user?.full_name}</td>
                                                <td className="py-2.5 text-center">
                                                    <span className="inline-flex items-center gap-1 rounded-full bg-green-50 px-2 py-0.5 text-xs font-semibold text-green-700">
                                                        <CheckCircle2 className="h-3 w-3" /> Terdaftar
                                                    </span>
                                                </td>
                                                <td className="py-2.5 text-right">
                                                    <Button
                                                        size="sm"
                                                        variant="ghost"
                                                        onClick={() => handleRemoveParticipant(managingParticipantsTraining.id, p.id)}
                                                        className="h-7 text-xs text-destructive hover:text-destructive"
                                                    >
                                                        Keluarkan
                                                    </Button>
                                                </td>
                                            </tr>
                                        ))}
                                        {(!managingParticipantsTraining.participants || managingParticipantsTraining.participants.length === 0) && (
                                            <tr>
                                                <td colSpan={4} className="py-6 text-center text-xs text-muted-foreground">
                                                    Belum ada toko UMK yang terdaftar di sesi pelatihan ini.
                                                </td>
                                            </tr>
                                        )}
                                    </tbody>
                                </table>
                            </div>

                            <DialogFooter>
                                <Button type="button" variant="outline" onClick={() => setSelectedTrainingId(null)}>
                                    Tutup
                                </Button>
                            </DialogFooter>
                        </DialogContent>
                    </Dialog>
                )}
            </div>
        </>
    );
}
