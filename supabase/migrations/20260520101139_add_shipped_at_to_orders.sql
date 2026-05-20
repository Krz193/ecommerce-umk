/*
|--------------------------------------------------------------------------
| Shipment Lifecycle Timestamp
|--------------------------------------------------------------------------
|
| Tracks operational shipment lifecycle.
|
| Order lifecycle:
|
| processing
| → shipped
| → completed
|
*/

alter table orders
add column shipped_at timestamptz;