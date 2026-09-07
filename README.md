# totp-raycast

A hotkey that generates your TOTP (6-digit authenticator app) code on your
computer, without needing your phone. macOS (Raycast/Hammerspoon) and
Windows (PowerShell/AutoHotkey) versions included.

Useful if your organization's MFA is normally tied to a phone-based
authenticator app (Microsoft Authenticator, Google Authenticator, etc.)
and you want to be able to sign in from your computer even when your phone
isn't handy — as long as your MFA provider supports registering a
generic/third-party authenticator app (most do, via an "I want to use a
different app" or "can't scan the QR code" option during setup).

**Read the [security trade-offs](#️-security-trade-offs--read-before-using-this)
section before setting this up.** This is a convenience tool, not a
security upgrade.

## How it works

TOTP codes are generated from a shared secret plus the current time —
your device and the server both compute the same 6-digit code
independently, no network call required. This project stores that secret
in your OS's credential store (macOS Keychain / Windows Credential
Manager — encrypted, unlocked when you're logged in) and gives you a
hotkey that reads it, computes the current code, and copies it to your
clipboard.

---

## macOS Setup

### Step 1: Get your TOTP secret

1. Go to your MFA provider's security settings page. For Microsoft/Entra
   accounts this is
   [mysignins.microsoft.com/security-info](https://mysignins.microsoft.com/security-info).
2. Click **Add sign-in method**.
3. Pick the option named **Microsoft Authenticator** (or just
   "Authenticator app" if that's what your provider calls it).
4. It'll ask you to install the app — ignore that and look for a small
   link near the bottom of the screen, worded something like **"I want
   to use a different authenticator app."** Click it.
   - If this link isn't there, your account is locked to the official
     app only, and this whole approach won't work for that account.
5. It now shows a QR code. Below it, click **"Can't scan the QR code?"**
6. This reveals a **Secret key** (a short string of letters/numbers) and
   sometimes a full **Setup URI** starting with `otpauth://`. Click
   **Copy key** (or copy the full URI if one is shown).
   - **This secret is shown once.** If you close this dialog before
     finishing setup, you'll need to start over from step 2 to get a
     new one — the old one stops working.
7. **Leave this browser tab open** — you'll come back to it in Step 3.
   Don't click Next yet.

### Step 2: Store the secret in Keychain

Open Terminal:

```bash
brew install oath-toolkit
```

Then run this — it will wait for input with no prompt shown:

```bash
read -rs OTPURL && security add-generic-password -a totp-seed -s totp -w "$OTPURL" && unset OTPURL
```

Paste the `otpauth://` URL you copied in Step 1 (build one yourself if
you only got a bare secret key — see the template below), press Enter.
Nothing will echo to the screen; that's expected.

Template if you only have a bare secret key, not a full URL:
```
otpauth://totp/ACCOUNT_NAME?secret=YOUR_SECRET_KEY&issuer=Microsoft
```

Verify it saved correctly:

```bash
security find-generic-password -a totp-seed -s totp -w
```

Should print your `otpauth://` URL back.

### Step 3: Get a code and finish registration

```bash
mkdir -p ~/raycast-scripts
cp raycast-scripts/totp.sh ~/raycast-scripts/totp.sh
chmod +x ~/raycast-scripts/totp.sh
~/raycast-scripts/totp.sh
```

This prints a 6-digit code and copies it to your clipboard. Go back to
the browser tab from Step 1 **right away** — codes expire after 30
seconds — paste the code into the verification box, and submit.

**Use the code this script just printed, not a code from your phone's
authenticator app.** If you already have a phone-based authenticator
set up, its codes come from a *different* secret than the one you just
registered here — they won't match.

### Step 4: Set up the Raycast hotkey

In Raycast: **Settings → Extensions → (+) → Add Script Directory**, and
select `~/raycast-scripts`. The "TOTP Code" command should now appear.

Click the hotkey field next to it and press whatever combo you want
(avoid ones already in use, like ⌘V).

Test it: press the hotkey, then paste anywhere. You should get a fresh
6-digit code each time, changing every 30 seconds.

### Optional: Hammerspoon auto-detect variant

`hammerspoon/init.lua.example` watches your browser and fires a
notification automatically when you land on a matching login page,
instead of requiring a manual hotkey press. See the comments in that
file for setup and for why you might *not* want this running all the
time (it polls your active browser tab continuously).

---

## Windows Setup

Windows doesn't have Raycast or Keychain, so this version uses Windows
Credential Manager for storage and a pure-PowerShell TOTP implementation
(no external binary needed — the algorithm is implemented directly in
`totp.ps1`).

### Step 1: Get your TOTP secret

Same process as macOS above:

1. Go to your provider's security page (e.g.
   [mysignins.microsoft.com/security-info](https://mysignins.microsoft.com/security-info)).
2. **Add sign-in method → Microsoft Authenticator**.
3. Click **"I want to use a different authenticator app"** near the
   bottom (not the QR scan prompt).
4. Click **"Can't scan the QR code?"**
5. Click **Copy key** to copy the secret to your clipboard.
6. **Leave the browser tab open** on this screen — don't click Next yet.

### Step 2: Store the secret in Credential Manager

Open PowerShell and run, pasting in what you copied:

```
cmdkey /generic:totp-seed /user:totp /pass:"otpauth://totp/ACCOUNT_NAME?secret=YOUR_SECRET_KEY&issuer=Microsoft"
```

Note: this puts the secret briefly in your PowerShell command history.
Clear it afterward (`Clear-History`), or use the `CredentialManager`
module instead for a prompt that doesn't echo or log it:

```powershell
Install-Module CredentialManager -Scope CurrentUser
$secureUrl = Read-Host -AsSecureString "Paste otpauth:// URL"
New-StoredCredential -Target "totp-seed" -UserName "totp" -SecurePassword $secureUrl -Persist LocalMachine
```

### Step 3: Get a code and finish registration

Download `totp.ps1` from this repo's `windows` folder to a known
location (e.g. Downloads), then in PowerShell:

```powershell
cd C:\Users\YourName\Downloads
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\totp.ps1
```

If you get a script-execution error, run this once first, then retry:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

This prints a 6-digit code and copies it to your clipboard. Go back to
the browser tab from Step 1 **immediately** — codes expire after 30
seconds — paste it into the verification box, and submit.

**Use the code the script just printed, not a code from your phone's
authenticator app.** If you already have a phone-based authenticator
set up, its codes come from a *different* secret than the one you just
registered here — they won't match. The code that verifies this new
method has to come from `totp.ps1`, freshly run, right before you
submit.

**Important:** don't reopen or restart the registration dialog partway
through this process. Every time you go through "Add sign-in method"
again, Microsoft generates a brand-new secret and the old one stops
working. Do steps 1 through 3 as one continuous pass, in the same
browser tab, without backing out.

### Step 4: Set up the AutoHotkey hotkey

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Download `hotkey.ahk` from this repo's `windows` folder into the
   **same folder** as `totp.ps1`.
3. Open `hotkey.ahk` in Notepad if you want to change the hotkey — the
   line to edit and a symbol reference table are right at the top.
   Default is `Ctrl+Alt+T`.
4. Right-click `hotkey.ahk` → **Run Script** (not double-click, which
   can open the AutoHotkey app dashboard instead).
5. You should see a green "H" icon appear in the system tray.
6. Test it: press your hotkey anywhere, you should get a toast
   notification with a fresh code.

To make it run automatically at login: right-click `hotkey.ahk` →
Create shortcut → move that shortcut into the Startup folder (press
Win+R, type `shell:startup`, Enter, drop it there).

---

## ⚠️ Security trade-offs — read before using this

This works, but it changes what your "second factor" actually protects
against. Know this before you rely on it:

- **Factor collapse.** If your TOTP secret and your password both end up
  reachable from the same unlocked computer (e.g. both stored in the same
  password manager or credential store), your two-factor login is now
  protected by one thing: your computer being unlocked. That's a real
  reduction in security compared to a code source that lives on a
  separate physical device.
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
- **Local storage is still a target.** Anything readable by your user
  account from the credential store (Keychain or Credential Manager) is
  readable by any process running as you, silently, with no prompt. The
  encryption protects against someone copying the raw file off disk — it
  doesn't protect against malicious software already running as you.
- **Keep a backup MFA method registered.** Don't delete your phone-based
  authenticator entry. If you lose access to this computer and its
  stored credential, you want another way back into your account that
  doesn't require an account-recovery process.

This is a convenience tool, not a security upgrade. Use it for
lower-stakes, frequent logins where phone friction is the main problem,
and prefer phishing-resistant methods (passkeys, hardware keys) wherever
your organization supports them.

## License

MIT — see [LICENSE](LICENSE).
