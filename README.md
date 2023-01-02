# MyApp

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Tutorial
We use `my_app` as its a generic and commonly used name. The `my` in `my_app` can be replaced with another abbreviation if desired. To do so, you can do the following:

1. Search for `my_app` to capture the configs.
2. Search for `MyApp` to capture all the function names.
3. Search for `My App` to capture all static text.
OR
- Search for: `my-app` and replace with: `my-awesome-app`.
- Search for: `my_app` and replace with: `my_awesome_app`.
- Search for: `MyApp` and replace with: `MyAwesomeApp`.
- Search for: `My App` and replace with: `My Awesome App`.


Create an .env file with the following content:
```bash
export MIX_ENV="prod"
export HOST="localhost"
export PHX_HOST="localhost"
export PHX_SERVER=true
export PHX_PORT="8080"
export PORT="8080"
export RELEASE_NAME="latest"
export SECRET_KEY_BASE="4OtKL7lQPW7LTXnBHFJ1KcOgkrV4dCOOCUnDsZ+foKrX5RFFrE+Udl+TCfpuNtVJ"
```
You can generate secret with the mix phx.gen secret command
```bash
mix phx.gen.secret
```

To test out a release build locally, we have a simple bash script for the deploy release commands:
```bash
#!/bin/bash

# Initial setup
mix deps.get --only prod
MIX_ENV=prod mix compile

# Compile assets
MIX_ENV=prod mix assets.deploy

# And run...
MIX_ENV=prod mix phx.gen.release

MIX_ENV=prod mix release
```

Now we can create a release with just:
```bash
bash .deploy-prod.sh   
```

and start the app with this command:
```bash
_build/prod/rel/my_app/bin/my_app start
```

Now visit you should have a phoenix app at [http://localhost:8080/](http://localhost:8080/)

#### Build Elixir Phoenix Docker image
To create a Docker image for our Elixir Phoenix application, we can use the Phoenix generator to create a Dockerfile:
```bash
mix phx.gen.release --docker
```

This will generate a Dockerfile with the following content:
```Dockerfile
# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20221004-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.14.2-erlang-25.1.2-debian-bullseye-20221004-slim
#
ARG ELIXIR_VERSION=1.14.2
ARG OTP_VERSION=25.1.2
ARG DEBIAN_VERSION=bullseye-20221004-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/my_app ./

USER nobody

CMD ["/app/bin/server"]
```

To build the Docker image named `my-app` with tag `latest`, run the following command:

```bash
docker build . -t my-app:latest
```


Add docker-compose.yml file 

**docker-compose.yml**
```yaml
version: '3.9'
services:
  web:
    image: "my_app-web:latest"
    volumes:
      - "./:/var/www/html/web:ro"
    mem_limit: 128m
    environment:
      Container: ELIXIR
      HOST: "${HOST}"
      PHX_HOST: "${PHX_HOST}"
      PHX_PORT: "80"
      PHX_SERVER: "${PHX_SERVER}"
      RELEASE_NAME: "${RELEASE_NAME}"
      MIX_ENV: "prod"
      SECRET_KEY_BASE: "0oE9YBt2T7m8HoD3jIk1e6UlMSPjHiuF2EklY3Tikda8r81N5jU1jv9VNpVtChBh"
      PORT: "${PORT}"
    ports:
      - "${PORT}:${PORT}"
  nginx-proxy:
    image: "nginx"
    ports:
      - "80:80"
    volumes:
      - "./:/var/www/html/my_app:ro"
      - "./proxy/conf.d:/etc/nginx/conf.d:ro"
    mem_limit: 128m
    links:
      - "web"
 ```

The NGINX configuration for `my_app` is located at `my_app/proxy/conf.d/my_app.conf`

**my_app/proxy/conf.d/my_app.conf**
```nginx
server {
  server_name localhost;

  listen 80;

  location / {
    allow all;

    # Proxy Headers
    proxy_http_version 1.1;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;
    proxy_set_header X-Cluster-Client-Ip $remote_addr;
    proxy_set_header Origin '';

    # The Important Websocket Bits!
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    
    proxy_pass http://web:8080;
  }
}
```

Here "proxy_
pass" is an NGINX directive that specifies the URL to which an HTTP request will be forwarded. In this case, the "http://web:8080" URL is being specified as the destination for the request. The "web" service refers to the "web" service defined in the docker-compose.yml file and the "8080" refers to the port number on which the service is running. This will proxy our app or, I mean `my_app` to [http://localhost/](http://localhost/)


One last thing, export the `database_url`:
```bash
export DATABASE_URL="postgres://<myuser>:<mypassword>@<my.db.host>:<mydbport>/<mydatabase>"
```

Run the docker-compose up command in detached mode
```bash
docker-compose up -d
```

Now you should be able to visit your Phoenix app at [http://localhost/](http://localhost/)
