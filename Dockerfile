FROM jenkins/jenkins:lts

USER root

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    unzip \
    xvfb \
    libxi6 \
    libgconf-2-4 \
    libnss3 \
    libatk1.0-0 \
    libxss1 \
    libasound2 \
    libgbm-dev \
    sudo && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o chrome.deb && \
    apt-get install -y ./chrome.deb || apt --fix-broken install -y && \
    rm chrome.deb

RUN CHROME_VERSION=$(google-chrome --version | awk '{print $3}' | cut -d. -f1) && \
    DRIVER_VERSION=$(curl -sSL https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROME_VERSION) && \
    curl -sSL https://chromedriver.storage.googleapis.com/${DRIVER_VERSION}/chromedriver_linux64.zip -o chromedriver.zip && \
    unzip chromedriver.zip && mv chromedriver /usr/local/bin/ && chmod +x /usr/local/bin/chromedriver && \
    rm chromedriver.zip

RUN pip3 install robotframework robotframework-seleniumlibrary

RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

USER jenkins




