<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StoreContent extends Model
{
    use HasFactory;

    protected $connection = 'marketplace';

    protected $table = 'store_contents';

    public $timestamps = false;

    protected $fillable = [
        'store_id',
        'product_id',
        'created_by',
        'title',
        'content_type',
        'body',
        'media_urls',
        'is_active',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'media_urls' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
