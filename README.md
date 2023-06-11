# Score Saver

This is a sourcemod plugin that saves a player's score when they disconnect or crash.

## Compatible Games
- Team Fortress 2
- Open Fortress

## Supported Platforms
- Linux

## Installation
Copy the `plugins` and `gamedata` directories to your `<game>/addons/sourcemod` directory.

## How It Works
When a player disconnects during a round, their current score will be saved until the map ends or there is a round reset.

If the player reconnects during the round, they will have their score set to value that was saved. Note that this *does not* save specific stats (assists, captures, headshots, etc.), only the player's raw score.

Note that for Open Fortress DM, the score saved will be the player's frag count instead of their total score.

## Credits
- Fraeven - Code, Testing  
- Rowedahelicon - Code, Testing