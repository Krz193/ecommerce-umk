<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Role extends Model
{
    use HasFactory;

    protected $connection = 'marketplace';

    protected $table = 'roles';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'slug',
        'description',
        'is_system',
        'created_at',
    ];

    protected $casts = [
        'is_system' => 'boolean',
        'created_at' => 'datetime',
    ];
}
