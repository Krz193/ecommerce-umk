<?php

namespace App\Services;

use App\Models\AdminAuditLog;
use Illuminate\Http\Request;

class AdminAuditLogger
{
    /**
     * @param  array<string, mixed>|null  $metadata
     */
    public function log(
        Request $request,
        string $action,
        string $targetType,
        string $targetId,
        string $reason,
        ?array $metadata = null,
    ): void {
        AdminAuditLog::query()->create([
            'admin_user_id' => $request->user()->id,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'reason' => $reason,
            'metadata' => $metadata,
        ]);
    }
}
