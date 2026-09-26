# The runner records the resolved image digests alongside the trial results.
FROM swift:6.3.2-noble AS builder
WORKDIR /workspace
COPY . .
WORKDIR /workspace/examples/deployment-trial
RUN swift build -c release --product TrialServer --jobs 4

FROM swift:6.3.2-noble
COPY --from=builder /workspace/examples/deployment-trial/.build/release/TrialServer /usr/local/bin/TrialServer
COPY --from=builder /workspace/examples/deployment-trial/Package.resolved /usr/local/share/daylily/Package.resolved
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/TrialServer"]
