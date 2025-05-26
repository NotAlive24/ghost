markdown
 👻 ghost Edition  
**Advanced Linux Anonymity Script | VPN > Tor > VPN > Tor Chaining | Dead-Man’s Switch | MAC & User-Agent Randomizer**

---

 📖 Overview

**ghost** is an advanced anonymity tool for Linux (Kali recommended). It chains **VPN > Tor > VPN > Tor** connections (as many times as you set), while periodically randomizing your **MAC address**, **User-Agent**, and **hostname** to confuse tracking systems and network admins.

It includes a **Dead-Man’s Switch** to instantly cut network connections if your VPN drops or your external IP changes.

---

 🔥 Features

- 🔒 VPN > Tor > VPN > Tor Chaining
- 🎭 MAC Address Randomization
- 🌐 User-Agent Rotation (Customizable Intervals)
- 🖥️ Random Hostname Generator
- 🚨 Dead-Man’s Switch (Auto Kills Network If IP Changes)
- 📝 Verbose Logging & Clean Exit Handler
- 💣 Dynamic Network Interface Detection
- ⚙️ Interactive Configuration At Launch

---

 📦 Requirements

Before using, make sure you have these installed:

- `openvpn`
- `tor`
- `curl`
- `iproute2` (for `ip` command)
- `macchanger`
- `sudo`

Install missing dependencies via:

```
sudo apt update && sudo apt install openvpn tor curl iproute2 macchanger -y
````

---

 ⚙️ How It Works

 1️⃣ Pre-Run Checks

* Verifies dependencies.
* Detects active network interface.
* Prompts for:

  * User-Agent swap interval.
  * MAC randomization interval.
  * Number of VPN > Tor chains.
  * Dead-Man’s Switch activation.

---

 2️⃣ Connection Chain

For each loop:

* Connects to VPN via OpenVPN.
* Starts Tor service.
* Randomizes:
  * MAC Address
  * User-Agent
  * Hostname
* Monitors your public IP for changes.
* If Dead-Man’s Switch triggers:
  * Blocks outbound connections via `iptables`.
  * Kills Tor and VPN.
  * Resets hostname, MAC.
  * Logs the event.
  * Exits cleanly.

---

 3️⃣ Cleanup

On exit (manual or triggered):

* Kills Tor, VPN, and dependent services.
* Restores `/etc/hosts`.
* Resets hostname to `kali`.
* Flushes DNS.
* Re-randomizes MAC one last time.
* Resets `iptables` if Dead-Man’s Switch triggered.
* Logs all cleanup actions.

---

 📝 What You Should Add Before Using

**Required Files:**

1. ✅ Your VPN `.ovpn` config file
   ➝ Place in the same directory or specify full path during prompt.

2. ✅ User-Agent text file (Optional)
   ➝ One User-Agent string per line.
   ➝ If omitted, defaults will be used.

**Commands to make executable:**

```
chmod +x ghost.sh
```

**Then run it:**

```
sudo ./ghost.sh
```
---

 🚨 Disclaimer

This tool is for **educational and lawful use only**. Misusing it for illegal activity is **your problem, not mine**. Know your laws before using this. Stay ethical, stay smart.

---

 ✅ What You Must Have / Do Before Running It:

- Install: `openvpn`, `tor`, `curl`, `iproute2`, `macchanger`
- Have your `.ovpn` VPN config file ready.
- Optionally, prepare a text file with User-Agent strings (if you want custom ones).
- Make sure your script is executable (`chmod +x ghost.sh`)
- Run as `sudo`

---
