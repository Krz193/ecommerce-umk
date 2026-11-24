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
        'social_platform',
        'media_format',
        'external_url',
        'body',
        'media_urls',
        'is_active',
        'reach_count',
        'likes_count',
        'comments_count',
        'shares_count',
        'inquiries_count',
        'created_at',
        'updated_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'media_urls' => 'array',
        'reach_count' => 'integer',
        'likes_count' => 'integer',
        'comments_count' => 'integer',
        'shares_count' => 'integer',
        'inquiries_count' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}
