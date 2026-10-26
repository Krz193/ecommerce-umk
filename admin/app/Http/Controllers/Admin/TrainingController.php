<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\Training;
use App\Models\TrainingParticipant;
use App\Services\AdminAuditLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class TrainingController extends Controller
{
    public function index(): Response
    {
        $trainings = Training::query()
            ->with(['participants.store:id,name', 'participants.user:id,full_name,phone'])
            ->withCount('participants')
            ->orderByDesc('schedule_at')
            ->get();

        $stores = Store::query()
            ->select('id', 'name', 'owner_id', 'status')
            ->where('status', 'active')
            ->orderBy('name')
            ->get();

        return Inertia::render('admin/trainings/index', [
            'trainings' => $trainings,
            'stores' => $stores,
        ]);
    }

    public function store(Request $request, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'instructor' => 'required|string|max:255',
            'schedule_at' => 'required|date',
            'location_or_url' => 'required|string|max:500',
            'max_participants' => 'required|integer|min:1|max:500',
            'status' => 'required|in:upcoming,ongoing,completed,cancelled',
            'report_summary' => 'nullable|string|max:5000',
            'documentation_urls' => 'nullable|array|max:10',
            'documentation_urls.*' => 'url:http,https|max:1000',
            'material_url' => 'nullable|url:http,https|max:1000',
        ]);

        $validated['documentation_urls'] = $validated['documentation_urls'] ?? [];

        $training = Training::create($validated);

        $auditLogger->log(
            $request,
            'trainings.create',
            'training',
            $training->id,
            "Membuat program pelatihan: {$training->title}",
            ['title' => $training->title, 'schedule_at' => $training->schedule_at->toIso8601String()]
        );

        return back()->with('success', 'Jadwal pelatihan berhasil dibuat.');
    }

    public function update(Request $request, Training $training, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'instructor' => 'required|string|max:255',
            'schedule_at' => 'required|date',
            'location_or_url' => 'required|string|max:500',
            'max_participants' => 'required|integer|min:1|max:500',
            'status' => 'required|in:upcoming,ongoing,completed,cancelled',
            'report_summary' => 'nullable|string|max:5000',
            'documentation_urls' => 'nullable|array|max:10',
            'documentation_urls.*' => 'url:http,https|max:1000',
            'material_url' => 'nullable|url:http,https|max:1000',
        ]);

        $validated['documentation_urls'] = $validated['documentation_urls'] ?? [];

        $training->update($validated);

        $auditLogger->log(
            $request,
            'trainings.update',
            'training',
            $training->id,
            "Memperbarui data pelatihan: {$training->title}",
            ['title' => $training->title, 'status' => $training->status]
        );

        return back()->with('success', 'Data pelatihan berhasil diperbarui.');
    }

    public function destroy(Request $request, Training $training, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $title = $training->title;
        $id = $training->id;
        $training->delete();

        $auditLogger->log(
            $request,
            'trainings.delete',
            'training',
            $id,
            "Menghapus jadwal pelatihan: {$title}",
            ['title' => $title]
        );

        return back()->with('success', 'Pelatihan berhasil dihapus.');
    }

    public function addParticipant(Request $request, Training $training, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $validated = $request->validate([
            'store_id' => 'required|uuid',
            'notes' => 'nullable|string',
        ]);

        $store = Store::findOrFail($validated['store_id']);

        $existing = TrainingParticipant::where('training_id', $training->id)
            ->where('store_id', $store->id)
            ->first();

        if ($existing) {
            return back()->with('error', 'Toko ini sudah terdaftar pada pelatihan.');
        }

        TrainingParticipant::create([
            'training_id' => $training->id,
            'store_id' => $store->id,
            'user_id' => $store->owner_id,
            'status' => 'registered',
            'notes' => $validated['notes'] ?? null,
            'registered_at' => now(),
        ]);

        $auditLogger->log(
            $request,
            'trainings.add_participant',
            'training_participant',
            $training->id,
            "Mendaftarkan toko {$store->name} ke pelatihan {$training->title}",
            ['store_name' => $store->name, 'training_title' => $training->title]
        );

        return back()->with('success', "Toko {$store->name} berhasil didaftarkan ke pelatihan.");
    }

    public function updateParticipant(Request $request, Training $training, TrainingParticipant $participant, AdminAuditLogger $auditLogger): RedirectResponse
    {
        abort_unless($participant->training_id === $training->id, 404);

        $validated = $request->validate([
            'status' => 'required|in:registered,attended,cancelled',
            'notes' => 'nullable|string|max:500',
        ]);

        $oldStatus = $participant->status;
        $participant->update($validated);

        $auditLogger->log(
            $request,
            'trainings.update_participant',
            'training_participant',
            $participant->id,
            "Mengubah kehadiran peserta pelatihan {$training->title} dari {$oldStatus} ke {$participant->status}",
            ['old_status' => $oldStatus, 'new_status' => $participant->status]
        );

        return back()->with('success', 'Status peserta berhasil diperbarui.');
    }

    public function removeParticipant(Request $request, Training $training, TrainingParticipant $participant, AdminAuditLogger $auditLogger): RedirectResponse
    {
        $id = $participant->id;
        $participant->delete();

        $auditLogger->log(
            $request,
            'trainings.remove_participant',
            'training_participant',
            $training->id,
            "Menghapus peserta dari pelatihan {$training->title}",
            ['participant_id' => $id]
        );

        return back()->with('success', 'Peserta berhasil dihapus dari pelatihan.');
    }
}
