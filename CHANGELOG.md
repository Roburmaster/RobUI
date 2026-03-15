# Changelog

All notable changes to RobUI will be documented in this file.

The format follows a simplified Keep a Changelog style.

## v0.7.9

xptracker removed. it will return as its own addon.
added /rgear and /ramr
Scanns all bags and you you can import gear string from askmrrobot. it will then find where your gear is. It will also create a shopping list for gems and such on the ah. Open ah click button and it will auto search for you.


## v0.7.84
Unit frame positioning system has been completely redesigned to ensure stable positioning when scaling frames.

All main unit frames (Player, Target, Target-of-Target, Focus, Pet) now use a new internal anchor + holder architecture. Position is stored on an unscaled anchor frame, while scaling is applied only to the holder frame. This prevents frames from drifting diagonally or shifting position when scale changes.

Frame movement now updates the anchor position directly, ensuring that scaling no longer affects the stored coordinates. This results in consistent behavior regardless of UI scale or frame scale settings.

Existing layouts may shift slightly on the first load after updating due to legacy coordinates from the previous positioning system. Moving a frame once will resave the position using the new system.

No gameplay logic was changed. Health, power, shields, heal prediction, textures, and update systems remain untouched. Only the internal positioning and scaling architecture was modified.

Installer layouts, import/export strings, and settings panels remain fully compatible with the new system.
---

## 0.7.8 – Initial Public Repository

Initial repository structure for the RobUI project.
world quest map item view now has /rwq to turn on or off. 
### Added

RobUI core addon structure  
RobUI Combat Grid system  
Custom unit frames (player, target, focus, pet)  
Class resource bars for multiple classes  
Aura system and aura configuration  
Castbar system  
Trinket tracking  
Combat utility modules  
Nameplate management system  
AutoSell and inventory utilities  
Character statistics and gear modules  
Font and media management

### Systems

Grid-based combat layout framework  
Modular UI architecture  
Shared database and configuration system

### Developer Notes

Project is under active development and the internal architecture may change frequently.
