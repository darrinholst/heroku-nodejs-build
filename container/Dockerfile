FROM darrinholst/heroku-nodejs:v8.9.2

ENV CI=true
ENV DOCKER=true

# install tools needed for docker install
RUN apt-get update && \
    apt-get install -y software-properties-common apt-transport-https && \
    apt-get clean

# install docker
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-get update && \
    apt-cache policy docker-ce && \
    apt-get install -y docker-ce && \
    apt-get clean && \
    docker -v

# install postgres stuff to get pg-native to build
RUN apt-get update && \
    apt-get install -y libpq-dev g++ && \
    apt-get clean

# copy the  scripts
COPY *.sh /
COPY *.js /
RUN chmod a+x /*.sh
