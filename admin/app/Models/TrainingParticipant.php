<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TrainingParticipant extends Model
{
    use HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'training_participants';

    protected $fillable = [
        'training_id',
        'store_id',
        'user_id',
        'status',
        'notes',
        'registered_at',
    ];

    protected $casts = [
        'registered_at' => 'datetime',
    ];

    public function training(): BelongsTo
    {
        return $this->belongsTo(Training::class, 'training_id');
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class, 'store_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(MarketplaceUser::class, 'user_id');
    }
}
