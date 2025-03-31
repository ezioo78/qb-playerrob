# QB Player Robbery Script

A FiveM script for QBCore framework that allows players to rob other players by accessing their inventory through a stash interface.

## Features

- Rob handcuffed or surrendered players by accessing their inventory
- Transfer items both ways - take items from target and return items if desired
- Admin integration through PS-AdminMenu for inventory viewing
- Compatible with latest QB-Inventory versions
- Drag and drop interface for easy item management
- Configurable police requirements, timeouts, and other settings
- Radial menu integration for easy access

## Dependencies

- [QBCore Framework](https://github.com/qbcore-framework/qb-core)
- [QB-Inventory](https://github.com/qbcore-framework/qb-inventory)
- [OxMySQL](https://github.com/overextended/oxmysql)
- [PS-AdminMenu](https://github.com/Project-Sloth/ps-adminmenu) (Optional for admin integration)

## Installation

1. Download or clone this repository
2. Place the `qb-playerrob` folder in your server's resources directory
3. Add `ensure qb-playerrob` to your server.cfg
4. Run the included database query if you don't already have an `inventories` table
5. Restart your server

## Usage

### Player Robbery

To rob a player:
1. Make sure they are handcuffed or surrendered
2. Be within 2.0 units of the target
3. Use one of these methods to start robbing:
   - Use the `/robplayer` command
   - Press F5 (default keybinding)
   - Use the radial menu option "Rob Player"
4. A stash interface will open showing the target's inventory
5. Drag items between inventories to take or return items
6. Close the interface when finished

### Admin Usage

If you have PS-AdminMenu installed, moderators and admins can:
1. Open the admin menu
2. Navigate to the player options
3. Select a player and use the "Open Inventory" option
4. View and modify the target player's inventory

## Configuration

All settings can be adjusted in the `config.lua` file:

```lua
Config = {}

-- General settings
Config.MinimumPolice = 2         -- Minimum police officers required for robbery
Config.RobberyTimeout = 600      -- Time in seconds before a player can be robbed again (10 minutes)
Config.RobberyDuration = 30      -- Time in seconds the robbery lasts before auto-completing
Config.AllowAllItems = true      -- When true, allows robbing all items; when false, restricts to RobbableItems list

-- Stash settings
Config.StashSlots = 30           -- Number of slots in the robbery stash
Config.StashWeight = 100000      -- Maximum weight for the robbery stash (set high to avoid restrictions)

-- Items that can be taken during a robbery (only used if AllowAllItems = false)
Config.RobbableItems = {
    "rolex",
    "goldchain",
    "diamond_ring",
    "cryptostick",
    -- Add more items here
}
```

## Commands

- `/robplayer` - Rob the closest player
- `/testinv [playerID]` - Test opening a specific player's inventory (admin/testing)
- `/listplayers` - Display a list of online players with their IDs (admin/testing)
- `/checkrobbery` - Check if the script is loaded properly

## Key Bindings

The default key binding for robbery is `F5`. This can be changed in the settings menu under "FiveM" > "Key Bindings" > "Rob Closest Player".

## Radial Menu Integration

This script integrates with the QBCore radial menu, adding a "Rob Player" option in the interactions menu. To enable this:

1. Open your radial menu configuration
2. Find the interactions section
3. Add the provided entry for player robbery

## Database Setup

If you don't already have an `inventories` table, run the following SQL query:

```sql
CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(255) NOT NULL,
  `items` longtext DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `maxweight` int(11) DEFAULT 100000,
  `slots` int(11) DEFAULT 50,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

## Development

This script uses standard QBCore event patterns and inventory management. Key components:

- `client.lua` - Handles player interactions and UI
- `server.lua` - Manages item transfers and database operations
- `config.lua` - Contains all configurable settings
- `fxmanifest.lua` - Resource manifest and dependencies

### Security Considerations

The script includes permission checks for admin functions and verification of player status before allowing robbery. It also prevents exploitation by requiring physical proximity and appropriate target state (handcuffed/surrendered).

## License

[MIT License](https://opensource.org/licenses/MIT)

## Support

For support, issues, or suggestions, please create an issue in the GitHub repository.