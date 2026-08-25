<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class MarketplaceUser extends Model
{
    use HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'users';

    protected $fillable = [
        'full_name',
        'username',
        'phone',
        'role',
        'avatar_url',
        'is_phone_verified',
    ];

    public function store(): HasOne
    {
        return $this->hasOne(Store::class, 'owner_id');
    }

    public function donations(): HasMany
    {
        return $this->hasMany(Donation::class, 'user_id');
    }

    public function trainingParticipations(): HasMany
    {
        return $this->hasMany(TrainingParticipant::class, 'user_id');
    }
}
