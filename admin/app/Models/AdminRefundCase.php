<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['order_id', 'status', 'reason', 'admin_notes', 'created_by', 'resolved_by', 'resolved_at'])]
class AdminRefundCase extends Model
{
    protected function casts(): array
    {
        return [
            'resolved_at' => 'datetime',
        ];
    }
}
