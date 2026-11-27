<?php

use App\Http\Controllers\Admin\DonationController;
use App\Models\Donation;
use App\Services\AdminAuditLogger;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

uses(TestCase::class);

test('DonationController blocks deleting paid or distributed donations', function (string $status) {
    $controller = new DonationController;
    $donation = new Donation(['status' => $status, 'amount' => 50000]);
    $auditLogger = Mockery::mock(AdminAuditLogger::class);
    $request = Request::create('/donations/test', 'DELETE');

    expect(fn () => $controller->destroy($request, $donation, $auditLogger))
        ->toThrow(ValidationException::class);
})->with(['paid', 'distributed']);
