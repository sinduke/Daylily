FROM swift:6.3.2-noble AS builder
WORKDIR /workspace
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
COPY examples/commerce-api ./examples/commerce-api
WORKDIR /workspace/examples/commerce-api/persistent
RUN swift build -c release --product PersistentCommerce --jobs 4

FROM swift:6.3.2-noble
COPY --from=builder /workspace/examples/commerce-api/persistent/.build/release/PersistentCommerce /usr/local/bin/PersistentCommerce
COPY --from=builder /workspace/examples/commerce-api/persistent/Package.resolved /usr/local/share/daylily/Package.resolved
USER 65532:65532
ENV HOST=0.0.0.0
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/PersistentCommerce"]
