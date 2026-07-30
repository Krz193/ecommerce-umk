<?php

use App\Http\Controllers\Admin\AuditLogController;
use App\Http\Controllers\Admin\CategoryController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\OrderLookupController;
use App\Http\Controllers\Admin\ProductModerationController;
use App\Http\Controllers\Admin\RefundCaseController;
use App\Http\Controllers\Admin\ReportController;
use App\Http\Controllers\Admin\StoreModerationController;
use App\Http\Controllers\Admin\UserLookupController;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Admin\RoleController;
use App\Http\Controllers\Admin\StoreContentController;

Route::redirect('/', '/login')->name('home');


Route::middleware(['auth', 'verified', 'admin'])->group(function () {
    Route::get('dashboard', DashboardController::class)->name('dashboard');

    // UMK Content & Promotions CRUD
    Route::get('store-contents', [StoreContentController::class, 'index'])->name('admin.store-contents.index');
    Route::post('store-contents', [StoreContentController::class, 'store'])->name('admin.store-contents.store');
    Route::patch('store-contents/{storeContent}', [StoreContentController::class, 'update'])->name('admin.store-contents.update');
    Route::delete('store-contents/{storeContent}', [StoreContentController::class, 'destroy'])->name('admin.store-contents.destroy');


    // Dynamic Roles & Permissions (RBAC)
    Route::get('roles', [RoleController::class, 'index'])->name('admin.roles.index');
    Route::post('roles', [RoleController::class, 'store'])->name('admin.roles.store');
    Route::patch('roles/{role}', [RoleController::class, 'update'])->name('admin.roles.update');
    Route::delete('roles/{role}', [RoleController::class, 'destroy'])->name('admin.roles.destroy');
    Route::post('users/{user}/roles', [RoleController::class, 'assignUserRole'])->name('admin.users.roles.assign');


    // Categories CRUD
    Route::get('categories', [CategoryController::class, 'index'])->name('admin.categories.index');
    Route::post('categories', [CategoryController::class, 'store'])->name('admin.categories.store');
    Route::patch('categories/{category}', [CategoryController::class, 'update'])->name('admin.categories.update');
    Route::delete('categories/{category}', [CategoryController::class, 'destroy'])->name('admin.categories.destroy');

    // Stores Moderation & CRUD
    Route::get('stores', [StoreModerationController::class, 'index'])->name('admin.stores.index');
    Route::post('stores', [StoreModerationController::class, 'store'])->name('admin.stores.store');
    Route::get('stores/{store}', [StoreModerationController::class, 'show'])->name('admin.stores.show');
    Route::patch('stores/{store}', [StoreModerationController::class, 'update'])->name('admin.stores.update');
    Route::delete('stores/{store}', [StoreModerationController::class, 'destroy'])->name('admin.stores.destroy');
    Route::patch('stores/{store}/approve', [StoreModerationController::class, 'approve'])->name('admin.stores.approve');
    Route::patch('stores/{store}/suspend', [StoreModerationController::class, 'suspend'])->name('admin.stores.suspend');
    Route::post('stores/{store}/assistants', [StoreModerationController::class, 'assignAssistant'])->name('admin.stores.assistants.assign');
    Route::delete('stores/{store}/assistants/{user}', [StoreModerationController::class, 'removeAssistant'])->name('admin.stores.assistants.remove');

    // Products Moderation & CRUD
    Route::get('products', [ProductModerationController::class, 'index'])->name('admin.products.index');
    Route::post('products', [ProductModerationController::class, 'store'])->name('admin.products.store');
    Route::get('products/{product}', [ProductModerationController::class, 'show'])->name('admin.products.show');
    Route::patch('products/{product}', [ProductModerationController::class, 'update'])->name('admin.products.update');
    Route::delete('products/{product}', [ProductModerationController::class, 'destroy'])->name('admin.products.destroy');
    Route::patch('products/{product}/archive', [ProductModerationController::class, 'archive'])->name('admin.products.archive');
    Route::patch('products/{product}/restore', [ProductModerationController::class, 'restore'])->name('admin.products.restore');

    Route::get('orders', [OrderLookupController::class, 'index'])->name('admin.orders.index');
    Route::get('orders/{order}', [OrderLookupController::class, 'show'])->name('admin.orders.show');

    Route::get('users', [UserLookupController::class, 'index'])->name('admin.users.index');
    Route::post('users', [UserLookupController::class, 'store'])->name('admin.users.store');
    Route::get('users/{user}', [UserLookupController::class, 'show'])->name('admin.users.show');
    Route::patch('users/{user}', [UserLookupController::class, 'update'])->name('admin.users.update');
    Route::delete('users/{user}', [UserLookupController::class, 'destroy'])->name('admin.users.destroy');


    Route::get('refund-cases', [RefundCaseController::class, 'index'])->name('admin.refund-cases.index');
    Route::get('refund-cases/create', [RefundCaseController::class, 'create'])->name('admin.refund-cases.create');
    Route::post('refund-cases', [RefundCaseController::class, 'store'])->name('admin.refund-cases.store');
    Route::get('refund-cases/{refundCase}', [RefundCaseController::class, 'show'])->name('admin.refund-cases.show');
    Route::patch('refund-cases/{refundCase}', [RefundCaseController::class, 'update'])->name('admin.refund-cases.update');

    Route::get('reports', [ReportController::class, 'index'])->name('admin.reports.index');
    Route::get('audit-logs', [AuditLogController::class, 'index'])->name('admin.audit-logs.index');
});

require __DIR__.'/settings.php';

