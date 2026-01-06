# Swisser Bank - Modern Banking System for QBCore

A high-quality, modern banking interface featuring savings goals, custom card designs, and multiple account tiers.

<div align="center">

## 👥 Credits

</div>

**Ballondorina & Special thanks to [Swisser Team](https://github.com/SwisserDev) for letting me use their Ai! Check them out [Swisser AI](https://ai.swisser.dev/)**  
 Thanks to OKOK for the inspiration!

<div align="center">

## 🛠 Dependencies

</div>
- **Framework:** QBCore/ESX

- **Database:** [oxmysql](https://github.com/overextended/oxmysql)

- **Lib:** [ox_lib](https://github.com/overextended/ox_lib)

- **Target:** [ox_target](https://github.com/overextended/ox_target)

<div align="center">

## 📦 Installation

</div>
1. Download the resource and place it in your `resources/[custom]` folder.
2. Import the provided `bank.sql` into your database.
3. Ensure you have the following assets in your `web/sounds` folders:
4. Add `ensure swisser_bank` to your `server.cfg` after `ox_lib` and `qb-core`/`es_extended`.

<div align="center">

## ⚙️ Configuration

</div>
- **Language:** Change `Config.Language` in `config.lua` to 'en' or 'sv'.
- **Interactions:** The script uses `ox_target` for ATMs and Bank Teller locations.
- **Notifications:** Choose between QBCore, ox_lib, Quasar, okok, or Brutal in `config.lua`.
<div align="center">

## ✨ Features

</div>
- Modern and responsive UI
- Multiple account tiers
- Money transfer on account number.
- Savings goals
- Custom card designs
- ATM Integration: Works with all standard ATMs
- Admin Dashboard: Comprehensive financial oversight

<div align="center">

## ⚙️ Technical Features

</div>
- Multi-Framework Support: Compatible with QBCore and ESX
- OxLib Integration: Optimized performance
- Customizable: Easy configuration and theming
- Multi-language Support: Built-in localization
<div align="center">

## ❓ FAQ

</div>

**Q: How can I change the language?**  
A: In the `config.lua` file, set `Config.Language` to either 'en' or 'sv'.

**Q: Is it compatible with QBCore/ESX?**  
A: Yes! The script automatically detects and works with both QBCore and ESX frameworks, using the appropriate framework based on what's running on your server.

**Q: Where can I get help?**  
A: Open a GitHub issue on our [repository](https://github.com/Ballondorina/Swiss-bank) Or [![Discord](https://img.shields.io/discord/1437113383672483882?style=for-the-badge&logo=discord&label=Discord&color=7289DA)](https://discord.gg/dHCHqRwBCk) for support.

---

<div align="center">
  
[![GitHub license](https://img.shields.io/github/license/Ballondorina/Swiss-bank?style=for-the-badge)](https://github.com/Ballondorina/Swiss-bank/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Ballondorina/Swiss-bank?style=for-the-badge)](https://github.com/Ballondorina/Swiss-bank/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/Ballondorina/Swiss-bank?style=for-the-badge)](https://github.com/Ballondorina/Swiss-bank/issues)
[![Discord](https://img.shields.io/discord/1437113383672483882?style=for-the-badge&logo=discord&label=Discord&color=7289DA)](https://discord.gg/dHCHqRwBCk)
</div>
