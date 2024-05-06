# Hello WebPros Docker Action

This action should very simply say Hello to WebPros.

## Inputs

## `who-to-greet`

**Required** The name of the person to greet. Default `"WebPros"`.

## Outputs

## `time`

The time the greeting commenced.

## Example usage

uses: actions/hello-world-docker-action@v2
with:
  who-to-greet: 'Mona the Octocat'

