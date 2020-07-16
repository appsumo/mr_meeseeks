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
ENV SLACK_CLIENT_ID=""
ENV SLACK_API_SECRET=""
ENV SLACK_AUTHORIZATION_ENDPOINT="https://slack.com/oauth/v2/authorize"
ENV SLACK_TOKEN_ENDPOINT="https://slack.com/api/oauth.v2.access"
ENV SLACK_VERIFICATION_TOKEN=""
ENV SLCK_SIGNING_SECRET=""
ENV SLACK_CHANEL="C01698A0S2H"
ENV AWS_REGION="us-west-2"
ENV BOT_ENDPOINT=""
ENV AWS_ACCESS_KEY_ID=""
ENV AWS_SECRET_ACCESS_KEY=""

CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-E", "production"]]
