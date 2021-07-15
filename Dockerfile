FROM jruby:9.2.19.0-jdk11

# JRuby available at /opt/jruby/bin/jruby

RUN set -x && \
    apt update && \
    apt install -y ruby ruby-dev build-essential git redis-server

# Due (old) EventMachine we need to OpenSSL 1.0 bits
WORKDIR /tmp
RUN wget http://deb.debian.org/debian/pool/main/o/openssl1.0/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
RUN dpkg -i libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
RUN wget http://deb.debian.org/debian/pool/main/o/openssl1.0/libssl1.0-dev_1.0.2u-1~deb9u1_amd64.deb
RUN dpkg -i libssl1.0-dev_1.0.2u-1~deb9u1_amd64.deb
RUN rm /tmp/*.deb

# MRI symlinked to /usr/bin/ruby (-> ruby2.5)

RUN echo 'gem: --no-document' >> /etc/gemrc

RUN /usr/bin/ruby -S gem install bundler -v '~> 2.1.4'

# Create jarvis (non-root) user for running the Ruby process
RUN addgroup --gid 1000 jarvis && \
    adduser --uid 1000 --gid 1000 --gecos "" --disabled-password jarvis

COPY --chown=jarvis:jarvis Gemfile* *.gemspec /usr/share/jarvis/

USER jarvis
WORKDIR /usr/share/jarvis
RUN /usr/bin/ruby -S bundle install --deployment

# Restore system ruby to JRuby
USER root
RUN update-alternatives --install /usr/local/bin/ruby ruby /opt/jruby/bin/jruby 1

ENV JRUBY_OPTS="--dev -J-Xmx1g"

# We also assume Bundler installed for commands run by Jarvis
RUN /opt/jruby/bin/jruby -S gem install bundler -v '~> 2.1.4'

COPY --chown=jarvis:jarvis . /usr/share/jarvis/

USER jarvis

#RUN ruby -v
# jruby 9.2.19.0 (2.5.8) 2021-06-15 55810c552b OpenJDK 64-Bit Server VM 11.0.11+9 on 11.0.11+9 [linux-x86_64]

#RUN env
# JRUBY_VERSION=9.2.19.0
# HOSTNAME=d80ab642f6dc
# HOME=/home/jarvis
# LANG=C.UTF-8
# BUNDLE_APP_CONFIG=/usr/local/bundle
# BUNDLE_SILENCE_ROOT_WARNING=1
# JRUBY_OPTS=--dev -J-Xmx1g
# JAVA_VERSION=11.0.11+9
# PATH=/usr/local/bundle/bin:/opt/jruby/bin:/usr/local/openjdk-11/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# JRUBY_SHA256=1f74885a2d3fa589fcbeb292a39facf7f86be3eac1ab015e32c65d32acf3f3bf
# GEM_HOME=/usr/local/bundle
# JAVA_HOME=/usr/local/openjdk-11
# PWD=/usr/share/jarvis

CMD /usr/bin/ruby bin/lita start --config lita_config.docker.rb
