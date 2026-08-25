<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SystemFeedback extends Model
{
    use HasFactory;

    protected $connection = 'marketplace';

    protected $table = 'system_feedbacks';

    public $timestamps = false;

    protected $fillable = [
        'user_id',
        'user_role',
        'category',
        'subject',
        'message',
        'status',
        'admin_notes',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
