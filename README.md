# Police-Chase-System
Advanced standalone Police Chase System for FiveM. Features a tactical NUI, realistic spike strip physics (wheel detachment), smart dispatch, and a real-time configuration tablet. Optimized &amp; ready to use. 🚀 Full details &amp; installation guide in the README.

When a player enters the driver's seat of any Police Class Vehicle, the standard mouse controls (Aim/Attack) are disabled and repurposed for the chase logic:

TARGET LOCK (Right Click / Mouse 2):

Aim at a suspect vehicle and press Right Click to lock on.

Smart Filter: The system prevents locking onto other police vehicles.

Cancel: Press Right Click again to disengage the target.

Once locked, a Progress Bar will appear and start filling based on speed and distance.

DEPLOY SPIKES (Left Click / Mouse 1):

Once the chase bar reaches 100%, the text changes to "SPIKES READY".

Press Left Click to deploy a spike strip behind your vehicle.

Safety Checks: Spikes can only be deployed if:

The target is at a safe distance.

You have the specific permission (Whitelisted in the panel).

Physics: The spikes will burst the target's tires and, after 5 seconds, physically detach a front wheel, forcing the vehicle to stop.

💻 ADMIN CONFIGURATION PANEL (/pcem)

The resource includes a high-quality, "Tactical/Cyberpunk" style tablet interface to configure every aspect of the script in real-time. No restart required.

Command: /pcem (Police Chase Edit Mode)
Requires Admin Permissions (see Installation below).

1. ⚙️ SETTINGS TAB

Adjust the core gameplay mechanics on the fly:

Min Speed: Minimum speed required to fill the chase bar.

Lock Distance: Max distance to maintain the lock.

Fill Rate: How fast the bar charges.

2. 👁️ VISUALS TAB

Customize the UI look to match your server's style:

Colors: Change the colors for the Bar, the Ready State, and the Text via a predefined palette.

Opacity: Adjust the transparency of the entire UI overlay.

3. 📡 DISPATCH TAB

Manage team communication:

Auto Dispatch: Toggle automatic alerts to other officers when the bar reaches 100%.

Blip Icons: Select the preferred blip sprite (Radar, Shield, Circle, etc.).

Blip Colors: Choose the color of the blip shown on the map for colleagues.

4. 🔒 ACCESS TAB

Security and Whitelist management:

Restrict Mode: If enabled, only players added to this list can deploy spikes.

ID List: Add or remove License/Steam IDs dynamically.

Note: Even if Restrict Mode is ON, non-whitelisted officers can still use the Target Lock and Dispatch features, but "DEPLOYMENT DENIED" will appear at 100%.

📦 INSTALLATION & PERMISSIONS

Download the resource and drop it into your resources folder.

