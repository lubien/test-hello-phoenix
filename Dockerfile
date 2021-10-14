ARG MIX_ENV="prod"

# Find eligible builder and runner images on Docker Hub
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=alpine
# https://hub.docker.com/_/alpine?tab=tags
ARG BUILDER_IMAGE="hexpm/elixir:1.12.3-erlang-24.1.2-alpine-3.14.2"
ARG RUNNER_IMAGE="alpine:3.14.2"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apk add --no-cache build-base git python3 curl

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ARG MIX_ENV
ENV MIX_ENV="${MIX_ENV}"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/$MIX_ENV.exs config/
RUN mix deps.compile

COPY priv priv

# note: if your project uses a tool like https://purgecss.com/,
# which customizes asset compilation based on what it finds in
# your Elixir templates, you will need to move the asset compilation
# step down so that `lib` is available.
COPY assets assets
RUN mix assets.deploy

# Compile the release
COPY lib lib

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy our custom release configuration and build the release
COPY rel rel

RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

WORKDIR "/app"
RUN apk add --no-cache libstdc++ openssl ncurses-libs && chown nobody:nobody /app

ARG MIX_ENV
USER nobody

COPY --from=builder --chown=nobody:nobody /app/_build/"${MIX_ENV}"/rel ./

RUN set -eux; \
  ln -nfs $(basename *)/bin/$(basename *) /app/entry

CMD /app/entry start
