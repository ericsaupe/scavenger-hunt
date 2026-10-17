# syntax=docker/dockerfile:1
FROM ruby:4.0.7-slim-bookworm AS base
WORKDIR /app
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT="development test" \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends ca-certificates curl libpq5 libvips42 libpoppler-glib8 libglib2.0-0 libyaml-0-2 xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && gem install bundler:4.0.23 --no-document

FROM base AS build
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends build-essential git libpq-dev libyaml-dev pkg-config \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm install -g yarn@1 \
  && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install && rm -rf "${BUNDLE_PATH}"/ruby/*/cache
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile
COPY . .
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then ./bin/install-ffmpeg; else apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/* && mkdir -p vendor/ffmpeg && ln -s /usr/bin/ffmpeg vendor/ffmpeg/ffmpeg && ln -s /usr/bin/ffprobe vendor/ffmpeg/ffprobe; fi
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && rm -rf node_modules tmp/cache

FROM base
ARG TARGETARCH
RUN if [ "$TARGETARCH" != "amd64" ]; then apt-get update -qq && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*; fi
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN mkdir -p tmp/pids log storage
COPY simulation/docker/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint
ENTRYPOINT ["entrypoint"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
