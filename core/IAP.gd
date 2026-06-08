extends Node
## IAP (autoload) — the SINGLE integration point for the one non-consumable
## "unlock all critters" purchase + Restore Purchases. COMPLIANCE: exactly one
## non-consumable product, no currency, no consumables, no randomized rewards.
##
## Today this is a clearly-marked STUB that grants the unlock locally so the full
## Shop flow is testable without the native plugin. To ship, implement the three
## TODO(iap) spots against a Godot 4 iOS in-app-purchase plugin. See
## docs/LAUNCH_PLAN.md → "Phase 6 — Monetization (IAP)" for exact install steps.

signal purchase_succeeded
signal purchase_failed(reason: String)
signal restore_completed(unlocked: bool)

## The real App Store Connect product identifier for the single unlock-all IAP.
const PRODUCT_ID := "com.critterdash.app.unlockall"

## True once a real store backend is connected (the stub leaves this false).
var available: bool = false

func _ready() -> void:
	# TODO(iap): detect the native plugin (e.g. Engine.has_singleton("InAppStore")),
	# initialize it, request product info, and set `available = true`.
	pass

## Localized price string for the Shop button. Falls back to a placeholder.
func price_text() -> String:
	# TODO(iap): return the store-provided localized price for PRODUCT_ID.
	return "$2.99"

## Begin the single unlock-all purchase.
func purchase_unlock_all() -> void:
	# TODO(iap): start the StoreKit purchase; on the success callback call _grant()
	# and emit purchase_succeeded; on failure emit purchase_failed(reason).
	# --- STUB (pre-plugin): grant immediately so the flow is testable ---
	_grant()
	emit_signal("purchase_succeeded")

## Restore a previously purchased non-consumable (required by App Store review).
func restore() -> void:
	# TODO(iap): ask the store to restore purchases; if the unlock is found,
	# call _grant() then emit restore_completed(true).
	# --- STUB: reflect whatever is already entitled locally ---
	emit_signal("restore_completed", SaveManager.all_unlocked_iap)

func _grant() -> void:
	SaveManager.set_all_unlocked(true)
