FROM elixir:latest

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mix escript.install --force github marcelotto/skout

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.mix/escripts