extends Node
## IAP (autoload) — the SINGLE integration point for the one non-consumable
## "unlock all critters" purchase + Restore Purchases. COMPLIANCE: exactly one
## non-consumable product, no currency, no consumables, no randomized rewards.
##
## Real StoreKit integration is implemented here against the Godot iOS
## "InAppStore" singleton (github.com/godotengine/godot-ios-plugins). It is
## FEATURE-DETECTED: if that singleton isn't present (desktop, CI, or before the
## native plugin is added to the export), this falls back to a clearly-marked
## local STUB that grants the unlock so the full Shop flow stays testable.
##
## To ship on device you still must (see docs/LAUNCH_PLAN.md → Phase 6):
##   1. add the InAppStore iOS plugin to the export,
##   2. create the non-consumable PRODUCT_ID in App Store Connect,
##   3. test a real purchase + restore in the StoreKit sandbox.
## Note: plugin event field names can vary slightly by version, so every event
## read below is defensive (.get with fallbacks).

signal purchase_succeeded
signal purchase_failed(reason: String)
signal restore_completed(unlocked: bool)

## The real App Store Connect product identifier for the single unlock-all IAP.
const PRODUCT_ID := "com.critterdash.app.unlockall"

## True once a real store backend is connected (the stub leaves this false).
var available: bool = false

var _store: Object = null            # the native InAppStore singleton, if present
var _poll: Timer = null              # drains the plugin's event queue
var _localized_price: String = ""    # store-provided price string once known

func _ready() -> void:
	# Detect the native iOS in-app-purchase plugin. Absent on desktop/CI → stub.
	if Engine.has_singleton("InAppStore"):
		_store = Engine.get_singleton("InAppStore")
		_init_store()

func _init_store() -> void:
	available = true
	# We finish transactions ourselves only after granting, so a purchase isn't
	# marked complete if the app dies mid-grant.
	_store.set_auto_finish_transaction(false)
	# The plugin posts results to an event queue; poll it a few times a second.
	_poll = Timer.new()
	_poll.wait_time = 0.25
	_poll.timeout.connect(_drain_events)
	add_child(_poll)
	_poll.start()
	# Ask the store for the localized title/price of our product.
	_store.request_product_info({"product_ids": [PRODUCT_ID]})

## Localized price string for the Shop button. Uses the store's value once known,
## otherwise a safe placeholder (also what the stub shows in development).
func price_text() -> String:
	return _localized_price if _localized_price != "" else "$2.99"

## Begin the single unlock-all purchase.
func purchase_unlock_all() -> void:
	if available and _store:
		var err: int = _store.purchase({"product_id": PRODUCT_ID})
		if err != OK:
			emit_signal("purchase_failed", "Could not start purchase")
		return
	# --- STUB (no native plugin): grant immediately so the flow is testable ---
	_grant()
	emit_signal("purchase_succeeded")

## Restore a previously purchased non-consumable (required by App Store review).
func restore() -> void:
	if available and _store:
		_store.restore_purchases()
		return
	# --- STUB: reflect whatever is already entitled locally ---
	emit_signal("restore_completed", SaveManager.all_unlocked_iap)

# ----------------------------------------------------------------- native events
func _drain_events() -> void:
	if _store == null:
		return
	while _store.get_pending_event_count() > 0:
		var e: Variant = _store.pop_pending_event()
		if e is Dictionary:
			_handle_event(e)

func _handle_event(e: Dictionary) -> void:
	match str(e.get("type", "")):
		"product_info":
			_on_product_info(e)
		"purchase":
			_on_purchase(e)
		"restore":
			_on_restore(e)

func _on_product_info(e: Dictionary) -> void:
	if str(e.get("result", "")) != "ok":
		return
	# Match our product id and cache its localized price (field name varies).
	var ids: Array = e.get("ids", [])
	var prices: Array = e.get("localized_prices", e.get("prices", []))
	for i in ids.size():
		if str(ids[i]) == PRODUCT_ID and i < prices.size():
			_localized_price = str(prices[i])

func _on_purchase(e: Dictionary) -> void:
	if str(e.get("result", "")) == "ok" and str(e.get("product_id", "")) == PRODUCT_ID:
		_grant()
		_finish(PRODUCT_ID)
		emit_signal("purchase_succeeded")
	else:
		emit_signal("purchase_failed", str(e.get("error", "Purchase failed")))

func _on_restore(e: Dictionary) -> void:
	if str(e.get("product_id", "")) == PRODUCT_ID:
		_grant()
		_finish(PRODUCT_ID)
	emit_signal("restore_completed", SaveManager.all_unlocked_iap)

func _finish(product_id: String) -> void:
	if _store and _store.has_method("finish_transaction"):
		_store.finish_transaction(product_id)

func _grant() -> void:
	SaveManager.set_all_unlocked(true)
