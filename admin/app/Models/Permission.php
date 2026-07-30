<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Permission extends Model
{
    use HasFactory;

    protected $connection = 'marketplace';

    protected $table = 'permissions';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'slug',
        'category',
        'created_at',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];
}
