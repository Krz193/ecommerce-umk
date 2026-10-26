<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Donation extends Model
{
    use HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'donations';

    protected $fillable = [
        'user_id',
        'store_id',
        'order_id',
        'amount',
        'donor_name',
        'donor_email',
        'donor_phone',
        'note',
        'status',
        'distributed_at',
        'distributed_amount',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'distributed_at' => 'datetime',
        'distributed_amount' => 'decimal:2',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class, 'store_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(MarketplaceUser::class, 'user_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }
}
