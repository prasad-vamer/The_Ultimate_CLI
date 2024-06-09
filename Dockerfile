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

RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
  dpkg -i session-manager-plugin.deb

# Copy the services directory to the container
COPY ./cli_services ./cli_services

# Make all .sh files in the services directory and its subdirectories executable
RUN find ./cli_services/services -type f -name "*.sh" -exec chmod +x {} \;

# Install CLI pager
RUN apt-get install less

# Install jq - tools jq to parse JSON in shell scripts.
RUN apt-get install jq -y

WORKDIR /usr/src/app/cli_services

CMD ["bash"]