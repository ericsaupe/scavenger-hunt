# Scavenger Hunt Party!

Scavenger Hunt Party! is a simple web app to manage the experience of a photo scavenger hunt. A photo scavenger hunt is a scavenger hunt where the participants are required to take a photo or video of the item for it to count as being found. When the scavenger hunt is over all participants can see the results as well as the photos and videos taken by others.

## Development

### Installation
- `bin/setup`

### Running
- `bin/dev`

### Testing
- `bin/test`

### Errors

- `[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called`
  - Seems to be an issue with Ruby and MacOS and VIPS and ImageMagick and whatever https://github.com/rails/rails/issues/38560. The fix is to run `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` before running the server.

## Adding New Scavenger Hunt Templates

One of the features of Scavenger Hunt is ready made hunt templates. These are loaded in during app boot from `app/templates`. To create a new scavenger hunt template just make a new YAML file in `app/templates` that is structured like a `Hunt` model with associated `Category`s and `Item`s.
