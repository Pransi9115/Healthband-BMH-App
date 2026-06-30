# 🚀 QUICK FIX GUIDE - GoNoise + Health Connect Sync

## 🔴 Your Error Message
```
"Sync failed — try again."
```

This appears when **Health Connect has no data to work with**.

---

## ⚡ FASTEST FIX (5 minutes)

### **Step 1: Open GoNoise App**
```
GoNoise → Settings/⚙️ → Look for:
  ✓ "Health Connect"
  ✓ "Health Integration"
  ✓ "Health Sharing"
  ✓ "Data Sync"
```

### **Step 2: Enable Health Connect in GoNoise**
```
Toggle ON (turn blue/green)
If asked for permissions → ALLOW ALL
```

### **Step 3: Manually Sync GoNoise**
```
GoNoise → Tap "Sync" or "⟳ Refresh"
Wait 30 seconds for data to upload
```

### **Step 4: Open Your BMH App**
```
Profile → Google Health Connect
Tap "Sync Now"
Should work now ✅
```

**If still fails → Continue below ↓**

---

## 🔍 DETAILED TROUBLESHOOTING

### **Scenario 1: "Sync failed" + No changes in GoNoise**

**Problem:** GoNoise doesn't have a Health Connect option

**Solutions:**
```
Option A: Update GoNoise
  1. Google Play Store
  2. Search "GoNoise" or "Noise"
  3. Tap "Update" if available
  4. Restart app
  5. Check for Health Connect option again

Option B: Check for Health Sync separately
  1. GoNoise → Settings
  2. Look for "Health Sync" or "Export"
  3. Try different settings menu locations
  4. Some devices: Settings → Health → Connected Apps

Option C: Try alternative health apps
  If GoNoise doesn't support Health Connect:
  • Download "Google Fit" app
  • Sync your smartwatch data there
  • Google Fit automatically sends to Health Connect
```

---

### **Scenario 2: "Permission not granted" error**

**Problem:** Health Connect permissions are missing or incomplete

**Fix:**

**Step 1: Check Android Permissions**
```
Phone Settings
  → Apps → Notifications
  → Search for your BMH app name
  → Tap it
  → "Permissions"
  → "Health"
  → Make sure ALL toggles are ON:
     ✓ Heart Rate
     ✓ Blood Oxygen
     ✓ Blood Pressure
     ✓ Sleep
     ✓ Steps
     ✓ Temperature
     ✓ (others)
```

**Step 2: Check GoNoise Permissions**
```
Do same process for GoNoise app
Make sure Health Connect is enabled there too
```

**Step 3: Restart Both Apps**
```
1. Force stop both GoNoise and BMH
2. Clear cache (optional):
   Settings → Apps → [App] → Storage → Clear Cache
3. Reopen GoNoise first
4. Let it sync (30 seconds)
5. Reopen BMH app
6. Try "Sync Now"
```

---

### **Scenario 3: Health Connect App Missing**

**Problem:** "Health Connect app not installed"

**Fix:**

Your phone may need the Health Connect app installed separately:

```
Google Play Store
  → Search "Google Health Connect"
  → Tap "Install"
  → Wait for installation
  → Open it once
  → Grant all permissions
```

Then:
```
GoNoise → Settings → Enable Health Connect
Your BMH App → Sync Now
```

---

### **Scenario 4: "Network Error" or Timeout**

**Problem:** Data sync is timing out

**Fix:**

```
1. Close all background apps
2. Switch to strong WiFi (not mobile data)
3. Wait 30 seconds
4. Try again

OR

1. Restart phone completely
2. Wait 1 minute
3. Open GoNoise
4. Wait for it to sync (watch the screen)
5. Then open BMH
6. Try Sync Now
```

---

### **Scenario 5: Data Shows in GoNoise But Not in Health Connect**

**Problem:** GoNoise has your smartwatch data, but it's not in Health Connect

**Symptoms:**
- GoNoise shows heart rate, steps, etc. ✓
- Health Connect shows nothing from GoNoise ✗
- Your BMH app syncs 0 metrics ✗

**Fix:**

**Option 1: Re-authorize GoNoise in Health Connect**
```
1. Open Health Connect app
2. Settings (gear icon)
3. Find GoNoise in the list
4. Tap it
5. Tap "Permissions" or "Re-connect"
6. Grant all permissions again
7. Close and reopen Health Connect
8. Check if GoNoise data appears
```

**Option 2: Use Google Fit as middleman**
```
1. Download Google Fit app from Play Store
2. Connect your Noise smartwatch to Google Fit
3. Let it sync (5-10 minutes)
4. Google Fit data automatically goes to Health Connect
5. Your BMH app can now read it
```

---

## ✅ Verification Checklist

Before hitting "Sync Now", verify:

- [ ] Noise smartwatch is connected to phone via Bluetooth
- [ ] GoNoise app shows your smartwatch data (HR, steps, etc.)
- [ ] GoNoise app has Health Connect enabled
- [ ] GoNoise app has Health Connect permissions granted
- [ ] Health Connect app is installed on your phone
- [ ] Your BMH app has Health Connect permissions in Android Settings
- [ ] You're on WiFi or strong mobile data
- [ ] You haven't used "Sync Now" in the last 30 seconds (cooldown)

---

## 🔧 Advanced: Manual Permission Reset

If nothing works, hard reset permissions:

```
Step 1: Uninstall/Reinstall
  Settings → Apps → [GoNoise]
  → "Storage" → "Clear Cache" AND "Clear Data"
  OR just uninstall and reinstall from Play Store

Step 2: Uninstall/Reinstall Your BMH App
  Same process

Step 3: Reconnect everything from scratch
  1. Open GoNoise
  2. Pair smartwatch again if needed
  3. Grant all Health Connect permissions
  4. Open BMH app
  5. Go to Profile → Google Health
  6. Tap "Connect Google Health"
  7. Grant all permissions
  8. Try "Sync Now"
```

---

## 📊 Expected vs Broken

### ✅ How it should look (WORKING)
```
GoNoise App:
  - Shows: 💓 72 HR, 👣 8234 steps, etc.

Health Connect App:
  - Shows multiple data sources including GoNoise

Your BMH App:
  - "Google Health Connect" shows "Connected"
  - "Sync Now" completes in 2-3 seconds
  - Shows "✅ Synced!" message
  - Optionally shows "Also found in Health Connect: GoNoise..."
```

### ❌ How it looks when BROKEN
```
GoNoise App:
  - ✓ Shows data (this part works fine)

Health Connect App:
  - ✗ Doesn't show GoNoise in data sources
  OR
  - Shows "GoNoise" but says "No data"

Your BMH App:
  - Shows "Sync failed — try again"
  - No data synced
```

---

## 🆘 Still Not Working?

**Get Debug Logs:**

1. **Open VS Code or Android Studio**
2. **Run flutter app with:**
   ```bash
   flutter run -v
   ```
3. **Do a sync from your app**
4. **Look for logs containing:**
   ```
   [HealthService] Starting Health Connect sync...
   [HealthService] Permission check result: true/false
   [HealthService] Read X data points from Health Connect
   [HealthService] Data sources found:
     - GoNoise: 5 points
     - Google Fit: 3 points
   ```

5. **Share the logs if still stuck**

---

## 🎯 What's Really Happening

```
Your Smartwatch (Noise Qube O2)
    ↓ Bluetooth
GoNoise App ✅ (This works!)
    ↓ (Should sync here)
Health Connect 
    ↓
Your BMH App

The break is at → GoNoise NOT → Health Connect
```

**Solution:** Configure GoNoise to export to Health Connect

That's it! Your code is fine, GoNoise just needs permission to share data.
