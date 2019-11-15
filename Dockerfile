FROM ruby:2.5-buster
run useradd -ms /bin/bash bot \
  && apt-get update \
  && LC_ALL=C DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends dumb-init \
  && gem install bundler -v 2.0.2
COPY ./ /home/bot
WORKDIR /home/bot
RUN bundle install
USER bot
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
HEALTHCHECK CMD curl --fail http://127.0.0.1:9292/health || exit 1
EXPOSE 9292
ENV SLACK_TOKEN="SETME"
ENV SLACK_CHANEL="#builds"
ENV AWS_ACCESS_KEY_ID="SETME"
ENV AWS_SECRET_ACCESS_KEY="SETME"
CMD ["rackup"]
