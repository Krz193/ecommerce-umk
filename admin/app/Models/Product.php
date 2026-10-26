<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Product extends Model
{
    use HasFactory, HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'products';
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'store_id',
        'category_id',
        'name',
        'slug',
        'description',
        'price',
        'stock',
        'product_type',
        'size',
        'color',
        'weight',
        'status',
    ];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class, 'store_id');
    }

    /**
     * Final selling price: (original - percent discount - fixed discount), then tax.
     * Never below zero; rounded to whole rupiah.
     */
    public static function calculateFinalPrice(
        float $originalPrice,
        float $discountPercent = 0,
        float $discountAmount = 0,
        float $taxPercent = 0,
    ): int {
        $afterDiscount = max(0, $originalPrice * (1 - $discountPercent / 100) - $discountAmount);

        return (int) round($afterDiscount * (1 + $taxPercent / 100));
    }
}
