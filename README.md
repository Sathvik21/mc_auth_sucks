# totp-raycast

A hotkey that generates your TOTP (6-digit authenticator app) code on your
Mac, without needing your phone.

Microsoft Auth is lowkey annoying if you're trying to lock in without using your phone, but all sign-ins need your phone because Microsoft Auth doesn't have a way to add a passkey on your laptop. 
Useful if your organization's MFA is normally tied to a phone-based
authenticator app (Microsoft Authenticator, Google Authenticator, etc.)
and you want to be able to sign in from your Mac even when your phone
isn't handy — as long as your MFA provider supports registering a
generic/third-party authenticator app (most do, via an "I want to use a
different app" or "can't scan the QR code" option during setup).

## How it works

TOTP codes are generated from a shared secret plus the current time —
your device and the server both compute the same 6-digit code
independently, no network call required. This project stores that secret
in your macOS login Keychain (encrypted, unlocked when you're logged in)
and gives you a Raycast hotkey that reads it, computes the current code
with `oathtool`, and copies it to your clipboard.

## Setup

### 1. Get your TOTP secret

When setting up a new authenticator method with your MFA provider, look
for an option like **"I want to use a different authenticator app"** or
**"Can't scan the QR code?"** — this reveals the setup key/URL instead of
forcing you through a phone-only flow. It'll look like:

```
otpauth://totp/YourService:you@example.com?secret=ABCD1234EFGH5678&issuer=YourService
```

Not every provider offers this — some restrict registration to their own
app. If you don't see this option, this approach won't work for that
account.

### 2. Store the secret in Keychain

```bash
brew install oath-toolkit

# Run this, then paste the otpauth:// URL when prompted and press enter.
# -s (silent) keeps it off your screen and out of shell history.
read -rs OTPURL && security add-generic-password -a totp-seed -s totp -w "$OTPURL" && unset OTPURL
```

Verify it saved correctly:

```bash
security find-generic-password -a totp-seed -s totp -w
```

Should print your `otpauth://` URL back.

### 3. Set up the Raycast script

```bash
mkdir -p ~/raycast-scripts
cp raycast-scripts/totp.sh ~/raycast-scripts/totp.sh
chmod +x ~/raycast-scripts/totp.sh
```

In Raycast: **Settings → Extensions → (+) → Add Script Directory**, and
select `~/raycast-scripts`. The "TOTP Code" command should now appear.
Assign it a hotkey (Settings → Extensions → find the command → click the
hotkey field → press your combo). Avoid combos that collide with
existing shortcuts like ⌘V.

Test it: press the hotkey, then paste. You should get a 6-digit code
that matches what your phone's authenticator app shows for the same
account.

### Optional: Hammerspoon auto-detect variant

`hammerspoon/init.lua.example` watches your browser and fires a
notification automatically when you land on a matching login page,
instead of requiring a manual hotkey press. See the comments in that
file for setup and for why you might *not* want this running all the
time (it polls your active browser tab continuously).

## ⚠️ Security trade-offs — read before using this

This works, but it changes what your "second factor" actually protects
against. Know this before you rely on it:

- **Factor collapse.** If your TOTP secret and your password both end up
  reachable from the same unlocked Mac (e.g. both stored in the same
  password manager or Keychain), your two-factor login is now protected
  by one thing: your Mac being unlocked. That's a real reduction in
  security compared to a code source that lives on a separate physical
  device.
- **TOTP is phishable.** A fake login page can ask for your password and
  your 6-digit code, then relay both to the real service within the
  ~30-second validity window. Push notifications with number matching,
  and passkeys/security keys, resist this because they're cryptographically
  bound to the real domain — TOTP has no such binding. If your account
  offers a passkey or hardware security key (e.g. YubiKey) and phishing
  resistance matters to you, that's the stronger option.
- **Some resources may reject it anyway.** Organizations with Conditional
  Access / phishing-resistant-MFA policies on sensitive resources (VPN,
  admin tools, financial systems) may reject a TOTP code even if it's
  accepted for everyday sign-in. You may still need your phone for those.
- **Local storage is still a target.** Anything readable by
  `security find-generic-password` under your user account is readable
  by any process running as you, silently, with no prompt. Keychain
  encryption protects against someone copying the raw file off disk —
  it doesn't protect against malicious software already running as you.
- **Keep a backup MFA method registered.** Don't delete your phone-based
  authenticator entry. If you lose access to your Mac and this Keychain
  entry, you want another way back into your account that doesn't
  require an account-recovery process.

This is a convenience tool, not a security upgrade. Use it for
lower-stakes, frequent logins where phone friction is the main problem,
and prefer phishing-resistant methods (passkeys, hardware keys) wherever
your organization supports them.

## License

MIT — see [LICENSE](LICENSE).
