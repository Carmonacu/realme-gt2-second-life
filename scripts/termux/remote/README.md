# Remote control from a second phone (Termux + Tailscale)

Templates for using another Android device as a **remote** for the Realme GT2 Termux host. Copy files to the **remote** phone (via Syncthing, `scp`, or `push-termux-boot.ps1` into `llm-setup/remote/`).

## 1. SSH key (once)

On the **remote** Termux:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_gt2 -N "" -C "remote-mando-gt2"
cat ~/.ssh/id_ed25519_gt2.pub
```

On the **Realme** (or paste the pubkey from PC with existing SSH):

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'PASTE_PUBLIC_KEY_ONE_LINE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Test:

```bash
ssh -i ~/.ssh/id_ed25519_gt2 -p 8022 u0_aNNN@100.x.y.z echo ok
```

Replace `100.x.y.z` with the Realme Tailscale IP (`tailscale ip -4` on the Realme or Tailscale admin).

## 2. `ssh gt2` (SSH config)

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
cp ~/storage/shared/Download/llm-setup/remote/ssh-config.example ~/.ssh/config
chmod 600 ~/.ssh/config
# edit HostName and IdentityFile if needed
ssh gt2   # interactive shell on Realme
ssh gt2 '~/bin/mode status'
```

Requires **Tailscale connected** on both phones. No `adb forward` needed from the remote device.

## 3. Shell shortcuts

```bash
cp ~/storage/shared/Download/llm-setup/remote/gt2-aliases.sh.example ~/gt2-aliases.sh
# optional: export GT2_TAILSCALE_IP=100.x.y.z before sourcing, or edit the file
echo 'source ~/gt2-aliases.sh' >> ~/.zshrc   # or ~/.bashrc
```

## One-shot install (OnePlus / second phone)

```bash
export GT2_TAILSCALE_IP=100.x.y.z   # Realme: tailscale ip -4
export GT2_SSH_USER=u0_aNNN          # Realme: whoami in Termux
bash install-oneplus-zsh.sh
```

## 4. Termux:Widget (optional)

Install **Termux:Widget** from F-Droid. Copy and chmod widget scripts under `~/.termux/widget/`. Optional: `pkg install termux-api` + **Termux:API** app for `termux-toast`.

## Portal :8081

Read-only dashboard. Mode changes still require SSH (or widgets above).

## Realme server shell (optional)

Minimal zsh on the **GT2** (not OMZ): copy [`gt2-server.zshrc`](gt2-server.zshrc) to `~/.zshrc` on the Realme and `chsh -s zsh`. Template is in repo; does not affect background services.
