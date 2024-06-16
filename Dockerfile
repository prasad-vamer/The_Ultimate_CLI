# Use the latest node image as of 2024/06/07
FROM node:22.2.0

# Set the working directory in the container
WORKDIR /usr/src/app

# Install dependencies
RUN apt-get update && \
  apt-get install -y \
  python3 \
  python3-pip \
  groff-base

# Install the AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && unzip awscliv2.zip
RUN ./aws/install

RUN npm install -g typescript
RUN npm install -g aws-cdk

# Setup the AWS configuration
COPY setup-aws-config.sh /setup-aws-config.sh
RUN chmod +x /setup-aws-config.sh
ENTRYPOINT ["/setup-aws-config.sh"]

CMD ["bash"]