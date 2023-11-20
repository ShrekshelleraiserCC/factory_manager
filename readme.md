# ComputerCraft Factory Manager
This is a program inspired by memories of Steve's Factory Manager.

This program allows you to graphically setup the flow of items, redstone, and whatever else through your factory. For example, if you setup one of each Create machine with an input and output chest, you could add nodes to represent each of these machines and connect them in various ways depending on what you would like to craft.

## Installation
### Automatic
Just run `wget run https://raw.githubusercontent.com/MasonGulu/cc_factory_manager/main/install.lua`

### Manual
You will need the following files, in the same directory structure
* `draw.lua`
* `item_filter.lua`
* `manager_lib.lua`
* `manager.lua`

If you actually want functionality you will need some types of connectors
* `connectors/inventory.lua`
* `connectors/redstone.lua`

If you require more functionality than just moving items around, you can download custom node types
* `nodes/filtering.lua`

There is an example filter included at `item_filter.lua`

## Usage
Run `manager` with no arguments to open a blank slate. You can optionally provide a filename as the first argument to open a saved factory.

Click the bottom button to open the context sensitive menu. Then use arrow keys and enter to navigate the menus.

If you need additional functionality, open up one of the connector or node files and make your own.