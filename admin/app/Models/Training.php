<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Training extends Model
{
    use HasUuids;

    protected $connection = 'marketplace';
    protected $table = 'trainings';

    protected $fillable = [
        'title',
        'description',
        'instructor',
        'schedule_at',
        'location_or_url',
        'max_participants',
        'status',
        'report_summary',
        'documentation_urls',
        'material_url',
    ];

    protected $casts = [
        'schedule_at' => 'datetime',
        'max_participants' => 'integer',
        'documentation_urls' => 'array',
    ];

    public function participants(): HasMany
    {
        return $this->hasMany(TrainingParticipant::class, 'training_id');
    }
}
