FROM ubuntu:22.04

RUN apt -y update
RUN apt -y install python3 python3-pip python3-wheel

WORKDIR /fpm
COPY . .
RUN mkdir /tmp/package-python-build

CMD python3 -m pip wheel --no-deps -w /tmp/package-python-build /fpm/spec/fixtures/python-pyproject.toml
