---
description: Audit the project against Kids Category / COPPA compliance rules
---

Audit this codebase against the non-negotiable compliance rules in `CLAUDE.md`.
Report findings as a checklist with file:line evidence. Do not change code unless
I ask — this is a read-only audit.

Check for:
1. **No data collection / network.** Search for `HTTPRequest`, `HTTPClient`,
   `http`, `tcp`, `udp`, socket usage, websockets, or any analytics SDK. Confirm
   `SaveManager` writes only to `user://` and nowhere else.
2. **No predatory monetization.** Confirm there is exactly one non-consumable IAP
   ("unlock all"), no currency, no randomized/loot-box rewards, no pay-to-win.
3. **Parental gate.** Confirm the Shop and any external link are reachable ONLY
   after `UIScreens.ParentalGate` passes.
4. **Gentleness.** Confirm the loss condition is recoverable (stumble-based, not
   instant death) and difficulty ramps gradually with no spikes.
5. **Privacy declaration.** Confirm `PRIVACY.md` says "Data Not Collected" and
   matches the actual behavior.

End with a clear PASS/FAIL per rule and a short list of any required fixes.
