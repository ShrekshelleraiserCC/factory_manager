# ComputerCraft Factory Manager
This is a program inspired by memories of Steve's Factory Manager.

This program allows you to graphically setup the flow of items, redstone, and whatever else through your factory. For example, if you setup one of each Create machine with an input and output chest, you could add nodes to represent each of these machines and connect them in various ways depending on what you would like to craft.

## Installation
### Automatic
Just run `wget run https://raw.githubusercontent.com/MasonGulu/cc_factory_manager/main/install.lua`

## Usage
Run `manager` with no arguments to open a blank slate. You can optionally provide a filename as the first argument to open a saved factory.

Click the bottom button to open the context sensitive menu. Then use arrow keys and enter to navigate the menus.

If you need additional functionality, open up one of the connector or node files and make your own.

## Terminology
Node: Rectangles which can be dragged around, each one can contain various numbers of input and output connectors. These can be used to represent a machine, some category, or as some special packet router.

Connector: Single character objects with a Node parent. Any input and output connector with the same `con_type` can be connected together, and packets sent from the output connector to the input connector.

Packet: Table containing data sent from linked output to input connectors. The content of each packet depends upon what type of connector it is.