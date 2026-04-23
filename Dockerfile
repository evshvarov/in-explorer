# ARG IMAGE=intersystemsdc/irishealth-community
# ARG IMAGE=intersystemsdc/iris-community
ARG IMAGE=containers.intersystems.com/intersystems/iris-community:2025.3

FROM $IMAGE

WORKDIR /home/irisowner/dev

ARG TESTS=0
ARG MODULE="esh-iris-table-stats"
ARG NAMESPACE="USER"


COPY .iris_init /home/irisowner/.iris_init

RUN wget https://pm.community.intersystems.com/packages/zpm/latest/installer -O /tmp/zpm.xml


RUN --mount=type=bind,src=.,dst=. \
    iris start IRIS && \
	iris session IRIS < iris.script && \
    ([ $TESTS -eq 0 ] || printf 'zn "%s"\nzpm "test %s -v -only"\nhalt\n' "$NAMESPACE" "$MODULE" | iris session IRIS) && \
    iris stop IRIS quietly

