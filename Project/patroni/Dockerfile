FROM postgres:17.6-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    gcc libpq-dev \
    curl jq build-essential libffi-dev libyaml-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /opt/venv

RUN /opt/venv/bin/pip install --no-cache-dir \
    "patroni[etcd]" \
    "psycopg2-binary"

ENV PATH="/opt/venv/bin:$PATH"

EXPOSE 5432 8008

ENTRYPOINT ["/opt/venv/bin/patroni"]
CMD ["/etc/patroni.yml"]