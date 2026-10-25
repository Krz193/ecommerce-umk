<?php

use App\Models\Product;

test('final price equals original price without discount or tax', function () {
    expect(Product::calculateFinalPrice(15000))->toBe(15000);
});

test('percent discount is applied before fixed discount and tax', function () {
    // 100000 - 10% = 90000 - 5000 = 85000, + 11% tax = 94350
    expect(Product::calculateFinalPrice(100000, 10, 5000, 11))->toBe(94350);
});

test('final price never goes below zero', function () {
    expect(Product::calculateFinalPrice(10000, 0, 50000, 11))->toBe(0);
});

test('final price is rounded to whole rupiah', function () {
    // 9999 * 0.95 = 9499.05
    expect(Product::calculateFinalPrice(9999, 5))->toBe(9499);
});
