# Music Files Directory

This directory contains audio files for the OnDemand music player widget.

## Supported Formats
- MP3 (.mp3)
- WAV (.wav)
- OGG (.ogg)

## Adding Music Files

1. Copy your audio files to this directory:
   ```
   cp your-song.mp3 /opt/ood/config/public/music/
   ```

2. Update the playlist in the widget file:
   `/opt/ood/config/apps/dashboard/views/widgets/_music_player.html.erb`

3. Add new tracks to the `<select>` element:
   ```html
   <option value="/public/music/your-song.mp3">Your Song Title</option>
   ```

4. Restart the OnDemand container for changes to take effect.

## Current Playlist
- Epic Battle Theme (epic-battle.mp3) - placeholder
- Victory Fanfare (victory-fanfare.mp3) - placeholder
- Ambient Hacking Sounds (ambient-hacking.mp3) - placeholder
- Victory Bell - external URL example

## External URLs
You can also reference music from external URLs (that support CORS) by adding them to the playlist options.