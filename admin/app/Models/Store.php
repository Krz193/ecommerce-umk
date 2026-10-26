<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Store extends Model
{
    use HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'stores';

    protected $fillable = [
        'owner_id',
        'name',
        'slug',
        'description',
        'status',
        'phone',
        'address',
    ];

    public function owner(): BelongsTo
    {
        return $this->belongsTo(MarketplaceUser::class, 'owner_id');
    }

    public function trainings(): HasMany
    {
        return $this->hasMany(TrainingParticipant::class, 'store_id');
    }

    public function donations(): HasMany
    {
        return $this->hasMany(Donation::class, 'store_id');
    }
}
