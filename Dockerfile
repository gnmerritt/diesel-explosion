FROM travisci/ci-garnet:packer-1512502276-986baf0

# apt-get update fails for some of the pre-installed repositories but we don't care
RUN apt-get update; apt-get -y install \
  git sudo postgresql-10 postgresql-client-10 curl gcc libpq-dev netcat pkg-config \
  libssl-dev nano gdb

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="${PATH}:~/.cargo/bin"
RUN ~/.cargo/bin/cargo install diesel_cli --no-default-features --features postgres

RUN git clone https://github.com/otterandrye/photothing-api.git/
WORKDIR photothing-api/
RUN git checkout find-libpq-bug
# lock rust nightly to a version that definitely works...
RUN echo "nightly-2018-09-28" > rust-toolchain

# compile with address sanitization enabled
ENV RUSTFLAGS="-Z sanitizer=address"
RUN ~/.cargo/bin/cargo test --no-run --target x86_64-unknown-linux-gnu

# need to give the tests dummy config values or they'll explode
ENV DATABASE_URL="postgres://postgres:1234@localhost:5433/travis_ci_test"
ENV AWS_ACCESS_KEY_ID="foo-bar-baz"
ENV AWS_SECRET_ACCESS_KEY="not-here"
ENV AWS_DEFAULT_REGION="us-east-1"
ENV ROCKET_S3_BUCKET_NAME="some-s3-bucket"
ENV ROCKET_CDN_URL="foo.cloudfront.net"

ENV RUST_BACKTRACE=1

# start PG, set up the test database, run diesel migrations & run the tests
# truncate the database to clean things up after each run
CMD service postgresql stop 9 \
  && service postgresql start 10 \
  && while ! nc -z localhost 5433; do echo "waiting for PG" && sleep 1; done \
  && sudo -u postgres psql -p 5433 -c "create database travis_ci_test;" -U postgres \
  && sudo -u postgres psql -p 5433 -c "alter user postgres password '1234';" -U postgres \
  && ~/.cargo/bin/diesel migration run \
  && dpkg --list | grep libpq \
  && echo '/tmp/core.%h.%e.%t' > /proc/sys/kernel/core_pattern \
  && ulimit -c unlimited \
  && ~/.cargo/bin/cargo test --target x86_64-unknown-linux-gnu \
  || sudo -u postgres psql -p 5433 -c "truncate table users cascade;" -U postgres \
  ; while true; do echo "failed, log in to investigate: docker exec -it <container id> bash -l" && sleep 30; done
