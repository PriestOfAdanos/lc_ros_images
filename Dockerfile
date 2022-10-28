ARG USERNAME=lc
ARG USER_UID=1000
ARG USER_GID=$USER_UID

##############################################
# Created from template ros2.dockerfile.jinja
##############################################

###########################################
# Base image 
###########################################
FROM ubuntu:20.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Install language
RUN apt-get update && apt-get install -y \
  locales \
  && locale-gen en_US.UTF-8 \
  && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8

# Install timezone
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y tzdata \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && rm -rf /var/lib/apt/lists/*

# Install ROS2
RUN  apt update &&  apt install curl gnupg2
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc |  apt-key add -
RUN  sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'
RUN  apt update &&  apt install -y \
  build-essential \
  cmake \
  git \
  python3-colcon-common-extensions \
  python3-pip \
  python-rosdep \
  python3-vcstool \
  wget
# install some pip packages needed for testing
RUN python3 -m pip install -U \
  argcomplete \
  flake8 \
  flake8-blind-except \
  flake8-builtins \
  flake8-class-newline \
  flake8-comprehensions \
  flake8-deprecated \
  flake8-docstrings \
  flake8-import-order \
  flake8-quotes \
  pytest-repeat \
  pytest-rerunfailures \
  pytest \
  pytest-cov \
  pytest-runner \
  setuptools
# install Fast-RTPS dependencies
RUN  apt install --no-install-recommends -y \
  libasio-dev \
  libtinyxml2-dev
# install Cyclone DDS dependencies
RUN  apt install --no-install-recommends -y \
  libcunit1-dev

RUN mkdir -p /opt/ros/galactic/src
RUN cd /opt/ros/galactic
RUN wget https://raw.githubusercontent.com/ros2/ros2/galactic/ros2.repos
RUN vcs import src < ros2.repos
RUN  rosdep init
RUN rosdep update
RUN rosdep install --from-paths src --ignore-src --rosdistro galactic -y --skip-keys "console_bridge fastcdr fastrtps libopensplice67 libopensplice69 rti-connext-dds-5.3.1 urdfdom_headers"
RUN  rosdep init
RUN rosdep update
RUN rosdep install --from-paths src --ignore-src --rosdistro galactic -y --skip-keys "console_bridge fastcdr fastrtps libopensplice67 libopensplice69 rti-connext-dds-5.3.1 urdfdom_headers"
RUN cd /opt/ros/galactic/
RUN colcon build --symlink-install

ENV ROS_DISTRO=galactic
ENV AMENT_PREFIX_PATH=/opt/ros/galactic
ENV COLCON_PREFIX_PATH=/opt/ros/galactic
ENV LD_LIBRARY_PATH=/opt/ros/galactic/lib
ENV PATH=/opt/ros/galactic/bin:$PATH
ENV PYTHONPATH=/opt/ros/galactic/lib/python3.8/site-packages
ENV ROS_PYTHON_VERSION=3
ENV ROS_VERSION=2
ENV DEBIAN_FRONTEND=

###########################################
#  Develop image 
###########################################
FROM base AS dev

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  bash-completion \
  build-essential \
  cmake \
  gdb \
  git \
  pylint3 \
  python3-argcomplete \
  python3-colcon-common-extensions \
  python3-pip \
  python3-rosdep \
  python3-vcstool \
  vim \
  wget \
  # Install ros distro testing packages
  ros-galactic-ament-lint \
  ros-galactic-launch-testing \
  ros-galactic-launch-testing-ament-cmake \
  ros-galactic-launch-testing-ros \
  python3-autopep8 \
  && rm -rf /var/lib/apt/lists/* \
  && rosdep init || echo "rosdep already initialized"

ARG USERNAME
ARG USER_UID
ARG USER_GID

# Create a non-root user
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  # [Optional] Add sudo support for the non-root user
  && apt-get update \
  && apt-get install -y sudo \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  # Cleanup
  && rm -rf /var/lib/apt/lists/* \
  && echo "source /usr/share/bash-completion/completions/git" >> /home/$USERNAME/.bashrc \
  && echo "if [ -f /opt/ros/${ROS_DISTRO}/setup.bash ]; then source /opt/ros/${ROS_DISTRO}/setup.bash; fi" >> /home/$USERNAME/.bashrc
ENV DEBIAN_FRONTEND=

###########################################
#  Full image 
###########################################
FROM dev AS ros-full

ENV DEBIAN_FRONTEND=noninteractive
# Install the full release
RUN apt-get update && apt-get install -y \
  ros-galactic-desktop \
  && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=
