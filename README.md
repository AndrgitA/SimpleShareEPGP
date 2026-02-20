# Simple Share EPGP

## 👑 Interface and Permissions 👥
Different interface depending on the switch

- 👑 For Master Looter (Admin)
- 👥 For Raid Member (Simple mode)

---
## 🚀 Main functionality

- 👑 - **✏️ Working with points** Add and subtract EP/GP for members
- 👑 - **😈 Decay:** Set % and apply decay for all points.
- 👑 - **📊 Offspec Price:** Set % value for offspec items.
- 👑 - **📦 Members:** Add, Remove, Set Class for member
- 👑 - **📥 Data Exchange (Import/Export):** A full GUI for moving your EPGP database via CSV strings (`Name;EP;GP;PR;Class`). Perfect for Google Sheets or Excel backups.
- 👑 - **✂️ Toggle filters:** `Raid Only`.
- 👥 - **🎲 Smart Bidding:** Players can bid using `+` (MainSpec) or `-` (OffSpec) in raid chat. The addon parses these in real-time, building a priority-sorted table.
- 👥 - **⚡ Interface mode:** Can switch interface mode for ML/Simple using.

---

## ⌨️ Chat Commands
`/sepgp` or `/simpleshareepgp`

| Command | Arguments | Description | Access |
| :--- | :--- | :--- | :---: |
| `/sepgp show` | `none` | Toggle the interactive Standings table | 👑 |
| `/sepgp bids` | `none` | Monitor active raid bids | 👑 |
| `/sepgp clearloot` | `none` | Clear loot data | 👑 |
| `/sepgp clearlogs` | `none` | Clear logs data | 👑 |
| `/sepgp offspec` | `none` | Change offspec % for price | 👑 |
| `/sepgp decay` | `none` | Apply the global decay percentage | 👑 |
| `/sepgp export_super_wow` | `none` | Export data to folder `Imports` | 👑 |
| `/sepgp restart` | `none` | Restart addon if having startup problems | 👥 / 👑 |

---
## 💾 SuperWoW Integration

If the **SuperWoW** mod is detected, SEPGP unlocks advanced logging:
*   **File Export:** Use `/sepgp export_super_wow` to instantly save your entire database into a `.txt` file inside your WoW folder with a timestamped filename.
---

## 📊 Data Management (Standings)

The addon supports deep customization of the rating display via the **Tablet-2.0**:


| Grouping Mode | Description |
| :--- | :--- |
| **Class** | Standard sorting by raid class. |
| **Armor** | Grouping by armor type (Cloth, Leather, Mail, Plate). |
| **Role** | Role division: Tank, Healer, Caster, Physics DPS. |

---
## 🛠️ Installation
1. Download the repository.
2. Extract the folder into your `Interface\AddOns\` directory.
3. **Important:** Ensure the folder is named exactly `SimpleShareEPGP` (remove any `-master` suffixes).
4. Optional: If u need u can also installing [`SimpleShareEPGPOptions`](https://github.com/AndrgitA/SimpleShareEPGPOptions). This mini addon for modify your prices, helping not loss price data if update main addon in next time.
5. Restart the game or reload the UI.

---
## 📜 Credits & Acknowledgements

*   **Original Repository:** This addon is a modification (**fork**) of the original **[shootyepgp](https://github.com/Road-block/shootyepgp)** addon. 
*   **License:** This project is distributed under the terms of the original project's license (where applicable). Please refer to the original repository for primary licensing details.

---
*Developed for the Vanilla 1.12+ community.*