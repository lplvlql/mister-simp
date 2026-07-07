# mister_simp

One script that migrates a standard MiSTer card layout into the simplified layout used by this repo.

## What it does

- Keeps the required root files and folders
- Removes everything else that is not on the allowlists
- Normalizes folder names to the canonical layout
- Installs the persistent helper scripts into `scripts/`
- Keeps the helper scripts current on later runs

## How to use it

- On MiSTer, run `mister-simp.sh` from `scripts/`
- With no argument, it runs on the parent folder of `scripts/`
- With a target path, it runs on that path instead

## Helper scripts

- `clean.sh` prunes and normalizes the layout
- `update.sh` syncs core files, game data, and helper scripts
- `cache.sh` builds the random-game cache
- `random.sh` picks a cached game and launches it
- `last.sh` reloads the last generated launch file
- `delete.sh` deletes the selected game and clears the launch file

## Notes

- Example before/after trees live in [`examples/`](./examples/)
- The migration entrypoint removes itself after a successful run
