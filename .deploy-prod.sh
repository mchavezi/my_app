#!/bin/bash

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
MIX_ENV=prod mix assets.deploy

# And run...
MIX_ENV=prod mix phx.gen.release

MIX_ENV=prod mix release