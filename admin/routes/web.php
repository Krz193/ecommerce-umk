<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\OrderLookupController;
use App\Http\Controllers\Admin\ProductModerationController;
use App\Http\Controllers\Admin\RefundCaseController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\StoreModerationController;
use App\Http\Controllers\Admin\UserLookupController;
use Illuminate\Support\Facades\Route;

Route::inertia('/', 'welcome')->name('home');

Route::middleware(['auth', 'verified', 'admin'])->group(function () {
    Route::get('dashboard', DashboardController::class)->name('dashboard');

    Route::get('stores', [StoreModerationController::class, 'index'])->name('admin.stores.index');
    Route::get('stores/{store}', [StoreModerationController::class, 'show'])->name('admin.stores.show');
    Route::patch('stores/{store}/approve', [StoreModerationController::class, 'approve'])->name('admin.stores.approve');
    Route::patch('stores/{store}/suspend', [StoreModerationController::class, 'suspend'])->name('admin.stores.suspend');

    Route::get('products', [ProductModerationController::class, 'index'])->name('admin.products.index');
    Route::get('products/{product}', [ProductModerationController::class, 'show'])->name('admin.products.show');
    Route::patch('products/{product}/archive', [ProductModerationController::class, 'archive'])->name('admin.products.archive');
    Route::patch('products/{product}/restore', [ProductModerationController::class, 'restore'])->name('admin.products.restore');

    Route::get('orders', [OrderLookupController::class, 'index'])->name('admin.orders.index');
    Route::get('orders/{order}', [OrderLookupController::class, 'show'])->name('admin.orders.show');

    Route::get('users', [UserLookupController::class, 'index'])->name('admin.users.index');
    Route::get('users/{user}', [UserLookupController::class, 'show'])->name('admin.users.show');

    Route::get('refund-cases', [RefundCaseController::class, 'index'])->name('admin.refund-cases.index');
    Route::get('refund-cases/create', [RefundCaseController::class, 'create'])->name('admin.refund-cases.create');
    Route::post('refund-cases', [RefundCaseController::class, 'store'])->name('admin.refund-cases.store');
    Route::get('refund-cases/{refundCase}', [RefundCaseController::class, 'show'])->name('admin.refund-cases.show');
    Route::patch('refund-cases/{refundCase}', [RefundCaseController::class, 'update'])->name('admin.refund-cases.update');

    Route::get('reports', [ReportController::class, 'index'])->name('admin.reports.index');
    Route::get('audit-logs', [AuditLogController::class, 'index'])->name('admin.audit-logs.index');
});

require __DIR__.'/settings.php';
